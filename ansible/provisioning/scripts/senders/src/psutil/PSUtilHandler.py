# Copyright (c) 2009, Jay Loden, Dave Daeschler, Giampaolo Rodola
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without modification,
# are permitted provided that the following conditions are met:
#
#  * Redistributions of source code must retain the above copyright notice, this
#    list of conditions and the following disclaimer.
#
#  * Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#
#  * Neither the name of the psutil authors nor the names of its contributors
#    may be used to endorse or promote products derived from this software without
#    specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
# ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
# ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import psutil
import platform

USAGE_FIELDS = ["user", "system"]
OPERATING_SYSTEM = platform.system()


class PSUtilHandler:

    @staticmethod
    def get_cpu_times():
        return psutil.cpu_times()

    @staticmethod
    def cpu_times_deltas(t1, t2):
        assert t1._fields == t2._fields, (t1, t2)
        deltas = {}
        for field in t1._fields:
            field_delta = getattr(t2, field) - getattr(t1, field)
            # CPU times are always supposed to increase over time
            # or at least remain the same and that's because time
            # cannot go backwards.
            # Surprisingly sometimes this might not be the case (at
            # least on Windows and Linux), see:
            # https://github.com/giampaolo/psutil/issues/392
            # https://github.com/giampaolo/psutil/issues/645
            # https://github.com/giampaolo/psutil/issues/1210
            # Trim negative deltas to zero to ignore decreasing fields.
            # top does the same. Reference:
            # https://gitlab.com/procps-ng/procps/blob/v3.3.12/top/top.c#L5063
            field_delta = max(0, field_delta)
            deltas[field] = field_delta
        return deltas

    @staticmethod
    def cpu_tot_time(times):
        tot = sum(times.values())
        if OPERATING_SYSTEM == "Linux":
            # On Linux guest times are already accounted in "user" or
            # "nice" times, so we subtract them from total.
            # Htop does the same. References:
            # https://github.com/giampaolo/psutil/pull/940
            # http://unix.stackexchange.com/questions/178045
            # https://github.com/torvalds/linux/blob/
            #     447976ef4fd09b1be88b316d1a81553f1aa7cd07/kernel/sched/
            #     cputime.c#L158
            tot -= times.get("guest", 0)  # Linux 2.6.24+
            tot -= times.get("guest_nice", 0)  # Linux 3.2.0+
        return tot

    @staticmethod
    def get_usages_from_deltas(t1, t2):
        # This method is called 'calculate' in the original implementation
        usages = {}
        deltas = PSUtilHandler.cpu_times_deltas(t1, t2)
        total_delta = PSUtilHandler.cpu_tot_time(deltas)
        # "scale" is the value to multiply each delta with to get percentages.
        # We use "max" to avoid division by zero (if total_delta is 0, then all
        # fields are 0 so percentages will be 0 too. total_delta cannot be a
        # fraction because cpu times are integers)
        scale = 100.0 / max(1, total_delta)
        for field in USAGE_FIELDS:
            field_perc =  deltas[field] * scale
            field_perc = round(field_perc, 1)
            # make sure we don't return negative values or values over 100%
            field_perc = min(max(0.0, field_perc), 100.0)
            usages[field] = field_perc
        return usages

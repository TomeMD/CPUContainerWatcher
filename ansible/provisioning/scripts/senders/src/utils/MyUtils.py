import os


class MyUtils:

    @staticmethod
    def create_dir(path):
        if not os.path.exists(path):
            os.makedirs(path)

    @staticmethod
    def clean_log_file(log_dir, path):
        for file in os.listdir(log_dir):
            full_path = f"{log_dir}/{file}"
            if os.path.isfile(full_path) and full_path == path:
                os.remove(full_path)

    @staticmethod
    def dict_lists_are_equal(l1, l2, key):
        l1_copy = l1.copy().sort(key=lambda d: d[key])
        l2_copy = l2.copy().sort(key=lambda d: d[key])
        return l1_copy == l2_copy
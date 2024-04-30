import os

def create_dir(path):

    if not os.path.exists(path):
        os.makedirs(path)


def clean_log_file(log_dir, path):
    for file in os.listdir(log_dir):
        full_path = f"{log_dir}/{file}"
        if os.path.isfile(full_path) and full_path == path:
            os.remove(full_path)

def container_lists_are_equal(l1, l2):
    l1_copy = l1.copy()
    l2_copy = l2.copy()
    l1_copy.sort(key= lambda d: d['pid'])
    l2_copy.sort(key= lambda d: d['pid'])
    return l1_copy == l2_copy
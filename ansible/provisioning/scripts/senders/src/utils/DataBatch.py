class DataBatch:

    def __init__(self, data_type):
        self.data = []
        self.length = 0
        self.data_type = data_type

    def get_length(self):
        return self.length

    def get_data(self):
        return self.data

    def add_data(self, dpt):
        if isinstance(dpt, self.data_type):
            self.data.append(dpt)
            self.length += 1
        else:
            raise TypeError(f"Expected data of type {self.data_type.__name__}, got {type(dpt).__name__}")

    def clear_data(self):
        self.data.clear()
        self.length = 0

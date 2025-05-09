import numpy as np

class Flatten:
    def __init__(self):
        self.original_shape = None

    def forward(self, x):
        """
        x shape: (batch_size, channels, height, width)
        Returns: (batch_size, channels * height * width)
        """
        self.original_shape = x.shape
        return x.reshape(x.shape[0], -1)

    def backward(self, d_out):
        """
        d_out shape: (batch_size, flattened_size)
        Returns: (batch_size, channels, height, width)
        """
        return d_out.reshape(self.original_shape)

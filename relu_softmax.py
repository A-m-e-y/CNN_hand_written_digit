import numpy as np

class ReLU:
    def __init__(self):
        self.mask = None

    def forward(self, x):
        self.mask = (x > 0)
        return x * self.mask

    def backward(self, d_out):
        return d_out * self.mask


class Softmax:
    def __init__(self):
        self.last_output = None

    def forward(self, x):
        """
        x shape: (batch_size, num_classes)
        """
        exp_shifted = np.exp(x - np.max(x, axis=1, keepdims=True))
        self.last_output = exp_shifted / np.sum(exp_shifted, axis=1, keepdims=True)
        return self.last_output

    def backward(self, d_out):
        """
        This is usually used with cross-entropy,
        so we assume d_out = predicted - one_hot_label
        """
        return d_out

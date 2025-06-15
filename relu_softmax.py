import numpy as np

class ReLU:
    """
    Rectified Linear Unit (ReLU) activation function.
    """
    def __init__(self):
        """
        Initializes the ReLU activation, setting up the mask for backpropagation.
        """
        self.mask = None

    def forward(self, x):
        """
        Applies the ReLU activation function to the input.

        Args:
            x (np.ndarray): Input array.

        Returns:
            np.ndarray: Output after applying ReLU (element-wise max(0, x)).
        """
        self.mask = (x > 0)
        return x * self.mask

    def backward(self, d_out):
        """
        Backward pass for ReLU activation.

        Args:
            d_out (np.ndarray): Gradient of the loss with respect to the output.

        Returns:
            np.ndarray: Gradient of the loss with respect to the input.
        """
        return d_out * self.mask


class Softmax:
    """
    Softmax activation function for multi-class classification.
    """
    def __init__(self):
        """
        Initializes the Softmax activation, storing the last output for backpropagation.
        """
        self.last_output = None

    def forward(self, x):
        """
        Applies the softmax function to the input.

        Args:
            x (np.ndarray): Input array of shape (batch_size, num_classes).

        Returns:
            np.ndarray: Softmax probabilities for each class.
        """
        exp_shifted = np.exp(x - np.max(x, axis=1, keepdims=True))
        self.last_output = exp_shifted / np.sum(exp_shifted, axis=1, keepdims=True)
        return self.last_output

    def backward(self, d_out):
        """
        Backward pass for softmax activation.

        Note: Typically used with cross-entropy loss, so assumes d_out = predicted - one_hot_label.

        Args:
            d_out (np.ndarray): Gradient of the loss with respect to the output.

        Returns:
            np.ndarray: Gradient of the loss with respect to the input.
        """
        return d_out

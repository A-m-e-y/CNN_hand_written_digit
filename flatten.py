import numpy as np

class Flatten:
    """
    Layer that flattens the input tensor except for the batch dimension.
    """
    def __init__(self):
        """
        Initializes the Flatten layer and stores the original shape for backpropagation.
        """
        self.original_shape = None

    def forward(self, x):
        """
        Flattens the input tensor except for the batch dimension.

        Args:
            x (np.ndarray): Input tensor of shape (batch_size, channels, height, width).

        Returns:
            np.ndarray: Flattened tensor of shape (batch_size, channels * height * width).
        """
        self.original_shape = x.shape
        return x.reshape(x.shape[0], -1)

    def backward(self, d_out):
        """
        Reshapes the gradient to the original input shape during backpropagation.

        Args:
            d_out (np.ndarray): Gradient of shape (batch_size, flattened_size).

        Returns:
            np.ndarray: Gradient reshaped to (batch_size, channels, height, width).
        """
        return d_out.reshape(self.original_shape)

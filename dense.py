import numpy as np

class Dense:
    """
    Fully connected (dense) neural network layer.

    Attributes:
        weights (np.ndarray): Weight matrix of shape (input_size, output_size).
        biases (np.ndarray): Bias vector of shape (output_size,).
    """
    def __init__(self, input_size, output_size):
        """
        Initializes the Dense layer with random weights and zero biases.

        Args:
            input_size (int): Number of input features.
            output_size (int): Number of output features.
        """
        # Weight initialization
        self.weights = np.random.randn(input_size, output_size) * 0.01
        self.biases = np.zeros(output_size)

        # Cache for backprop
        self.last_input = None
        self.last_output = None

    def sw_dot(self, A, B, C):
        """
        Computes the dot product of A and B, then adds C.

        Args:
            A (np.ndarray): Input matrix.
            B (np.ndarray): Weight matrix.
            C (np.ndarray): Bias vector.

        Returns:
            np.ndarray: Result of (A @ B) + C.
        """
        return np.dot(A, B) + C
    
    def forward(self, x):
        """
        Performs the forward pass of the dense layer.

        Args:
            x (np.ndarray): Input tensor of shape (batch_size, input_size).

        Returns:
            np.ndarray: Output tensor of shape (batch_size, output_size).
        """
        self.last_input = x
        # output = np.dot(x, self.weights) + self.biases
        output = self.sw_dot(x, self.weights, self.biases)
        self.last_output = output
        return output

    def backward(self, d_out, learning_rate):
        """
        Performs the backward pass, computing gradients and updating weights.

        Args:
            d_out (np.ndarray): Gradient of the loss with respect to the output (batch_size, output_size).
            learning_rate (float): Learning rate for parameter updates.

        Returns:
            np.ndarray: Gradient of the loss with respect to the input.
        """
        d_input = np.dot(d_out, self.weights.T)
        d_weights = np.dot(self.last_input.T, d_out)
        d_biases = np.sum(d_out, axis=0)

        # Update weights and biases
        self.weights -= learning_rate * d_weights
        self.biases -= learning_rate * d_biases

        return d_input

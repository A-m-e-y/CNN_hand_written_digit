import numpy as np

class Dense:
    def __init__(self, input_size, output_size):
        # Weight initialization
        self.weights = np.random.randn(input_size, output_size) * 0.01
        self.biases = np.zeros(output_size)

        # Cache for backprop
        self.last_input = None
        self.last_output = None

    def forward(self, x):
        """
        x shape: (batch_size, input_size)
        Returns: (batch_size, output_size)
        """
        self.last_input = x
        output = np.dot(x, self.weights) + self.biases
        self.last_output = output
        return output

    def backward(self, d_out, learning_rate):
        """
        d_out shape: (batch_size, output_size)
        """
        d_input = np.dot(d_out, self.weights.T)
        d_weights = np.dot(self.last_input.T, d_out)
        d_biases = np.sum(d_out, axis=0)

        # Update weights and biases
        self.weights -= learning_rate * d_weights
        self.biases -= learning_rate * d_biases

        return d_input

import numpy as np

class Neuron:
    """
    Represents a single artificial neuron with forward and backward propagation.

    Attributes:
        weights (np.ndarray): Weights for the neuron's inputs.
        bias (float): Bias term.
        grad_w (np.ndarray): Gradient of the loss with respect to weights.
        grad_b (float): Gradient of the loss with respect to bias.
    """
    def __init__(self, input_size):
        """
        Initializes the neuron with random weights and zero bias.

        Args:
            input_size (int): Number of input features.
        """
        # Initialize weights and bias with small random values
        self.weights = np.random.randn(input_size) * 0.01
        self.bias = 0.0

        # Gradients for weight and bias
        self.grad_w = np.zeros_like(self.weights)
        self.grad_b = 0.0

        # Inputs and output cache for backprop
        self.last_input = None
        self.last_output = None

    def forward(self, x):
        """
        Computes the output of the neuron for input x.

        Args:
            x (np.ndarray): Input vector.

        Returns:
            float: Output value (pre-activation).
        """
        self.last_input = x
        z = np.dot(self.weights, x) + self.bias
        self.last_output = z
        return z

    def backward(self, d_out):
        """
        Computes gradients for weights and bias, and propagates the gradient backward.

        Args:
            d_out (float): Gradient of the loss with respect to the neuron's output.

        Returns:
            np.ndarray: Gradient of the loss with respect to the neuron's input.
        """
        # Gradient of loss w.r.t weights and bias
        self.grad_w = d_out * self.last_input
        self.grad_b = d_out

        # Gradient of loss w.r.t input to this neuron
        return d_out * self.weights

    def update(self, lr):
        """
        Updates the neuron's weights and bias using the computed gradients.

        Args:
            lr (float): Learning rate.
        """
        self.weights -= lr * self.grad_w
        self.bias -= lr * self.grad_b

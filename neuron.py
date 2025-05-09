import numpy as np

class Neuron:
    def __init__(self, input_size):
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
        self.last_input = x
        z = np.dot(self.weights, x) + self.bias
        self.last_output = z
        return z

    def backward(self, d_out):
        # Gradient of loss w.r.t weights and bias
        self.grad_w = d_out * self.last_input
        self.grad_b = d_out

        # Gradient of loss w.r.t input to this neuron
        return d_out * self.weights

    def update(self, lr):
        self.weights -= lr * self.grad_w
        self.bias -= lr * self.grad_b

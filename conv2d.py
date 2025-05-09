import numpy as np

class Conv2D:
    def __init__(self, in_channels, out_channels, kernel_size, stride=1, padding=0):
        self.in_channels = in_channels
        self.out_channels = out_channels
        self.kernel_size = kernel_size if isinstance(kernel_size, tuple) else (kernel_size, kernel_size)
        self.stride = stride
        self.padding = padding

        # Initialize weights (filters) and biases
        self.weights = np.random.randn(out_channels, in_channels, *self.kernel_size) * 0.1
        self.biases = np.zeros(out_channels)

        # Caches for backprop
        self.last_input = None

    def _pad_input(self, x):
        if self.padding == 0:
            return x
        return np.pad(x, ((0, 0), (0, 0), 
                          (self.padding, self.padding), 
                          (self.padding, self.padding)), mode='constant')

    def forward(self, x):
        """
        x shape: (batch_size, in_channels, height, width)
        """
        self.last_input = x
        batch_size, _, in_h, in_w = x.shape
        kh, kw = self.kernel_size
        out_h = (in_h + 2 * self.padding - kh) // self.stride + 1
        out_w = (in_w + 2 * self.padding - kw) // self.stride + 1

        x_padded = self._pad_input(x)
        out = np.zeros((batch_size, self.out_channels, out_h, out_w))

        for b in range(batch_size):
            for oc in range(self.out_channels):
                for i in range(0, out_h):
                    for j in range(0, out_w):
                        h_start = i * self.stride
                        w_start = j * self.stride
                        window = x_padded[b, :, h_start:h_start+kh, w_start:w_start+kw]
                        out[b, oc, i, j] = np.sum(window * self.weights[oc]) + self.biases[oc]

        return out

    def backward(self, d_out, learning_rate):
        """
        d_out shape: same as output of forward
        """
        x = self.last_input
        batch_size, _, in_h, in_w = x.shape
        kh, kw = self.kernel_size
        x_padded = self._pad_input(x)
        d_x_padded = np.zeros_like(x_padded)
        d_w = np.zeros_like(self.weights)
        d_b = np.zeros_like(self.biases)

        out_h = d_out.shape[2]
        out_w = d_out.shape[3]

        for b in range(batch_size):
            for oc in range(self.out_channels):
                for i in range(out_h):
                    for j in range(out_w):
                        h_start = i * self.stride
                        w_start = j * self.stride
                        window = x_padded[b, :, h_start:h_start+kh, w_start:w_start+kw]
                        d_w[oc] += d_out[b, oc, i, j] * window
                        d_b[oc] += d_out[b, oc, i, j]
                        d_x_padded[b, :, h_start:h_start+kh, w_start:w_start+kw] += d_out[b, oc, i, j] * self.weights[oc]

        # Remove padding from gradient if any
        if self.padding != 0:
            d_x = d_x_padded[:, :, self.padding:-self.padding, self.padding:-self.padding]
        else:
            d_x = d_x_padded

        # Update weights and biases
        self.weights -= learning_rate * d_w
        self.biases -= learning_rate * d_b

        return d_x

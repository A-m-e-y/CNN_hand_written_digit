import pickle
from conv2d import Conv2D
from dense import Dense
from flatten import Flatten
from relu_softmax import ReLU, Softmax

NUM_CLASSES = 10

class SimpleCNN:
    def __init__(self):
        self.conv = Conv2D(in_channels=1, out_channels=4, kernel_size=3, stride=1, padding=1)
        self.relu1 = ReLU()
        self.flatten = Flatten()
        self.dense1 = Dense(input_size=4 * 28 * 28, output_size=64)
        self.relu2 = ReLU()
        self.dense2 = Dense(input_size=64, output_size=NUM_CLASSES)
        self.softmax = Softmax()

    def forward(self, x):
        x = self.conv.forward(x)
        x = self.relu1.forward(x)
        x = self.flatten.forward(x)
        x = self.dense1.forward(x)
        x = self.relu2.forward(x)
        x = self.dense2.forward(x)
        x = self.softmax.forward(x)
        return x

    def backward(self, d_out, lr):
        d_out = self.dense2.backward(d_out, lr)
        d_out = self.relu2.backward(d_out)
        d_out = self.dense1.backward(d_out, lr)
        d_out = self.flatten.backward(d_out)
        d_out = self.relu1.backward(d_out)
        d_out = self.conv.backward(d_out, lr)

    def save(self, path):
        params = {
            'conv_w': self.conv.weights,
            'conv_b': self.conv.biases,
            'dense1_w': self.dense1.weights,
            'dense1_b': self.dense1.biases,
            'dense2_w': self.dense2.weights,
            'dense2_b': self.dense2.biases
        }
        with open(path, 'wb') as f:
            pickle.dump(params, f)

    def load(self, path):
        with open(path, 'rb') as f:
            params = pickle.load(f)
        self.conv.weights = params['conv_w']
        self.conv.biases = params['conv_b']
        self.dense1.weights = params['dense1_w']
        self.dense1.biases = params['dense1_b']
        self.dense2.weights = params['dense2_w']
        self.dense2.biases = params['dense2_b']

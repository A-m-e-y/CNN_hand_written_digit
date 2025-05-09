import pickle
from conv2d import Conv2D
from dense import Dense
from flatten import Flatten
from relu_softmax import ReLU, Softmax

NUM_CLASSES = 10

class SimpleCNN:
    def __init__(self):
        # Conv Block 1
        self.conv1 = Conv2D(in_channels=1, out_channels=8, kernel_size=3, stride=1, padding=1)
        self.relu1 = ReLU()

        # Conv Block 2
        self.conv2 = Conv2D(in_channels=8, out_channels=32, kernel_size=3, stride=1, padding=1)
        self.relu2 = ReLU()

        # Conv Block 3
        self.conv3 = Conv2D(in_channels=32, out_channels=64, kernel_size=3, stride=1, padding=1)
        self.relu3 = ReLU()

        # Flatten and Dense
        self.flatten = Flatten()
        self.dense1 = Dense(input_size=64 * 28 * 28, output_size=128)
        self.relu_fc = ReLU()
        self.dense2 = Dense(input_size=128, output_size=NUM_CLASSES)
        self.softmax = Softmax()

    def forward(self, x):
        x = self.conv1.forward(x)
        x = self.relu1.forward(x)

        x = self.conv2.forward(x)
        x = self.relu2.forward(x)

        x = self.conv3.forward(x)
        x = self.relu3.forward(x)

        x = self.flatten.forward(x)
        x = self.dense1.forward(x)
        x = self.relu_fc.forward(x)
        x = self.dense2.forward(x)
        x = self.softmax.forward(x)
        return x

    def backward(self, d_out, lr):
        d_out = self.dense2.backward(d_out, lr)
        d_out = self.relu_fc.backward(d_out)
        d_out = self.dense1.backward(d_out, lr)
        d_out = self.flatten.backward(d_out)

        d_out = self.relu3.backward(d_out)
        d_out = self.conv3.backward(d_out, lr)

        d_out = self.relu2.backward(d_out)
        d_out = self.conv2.backward(d_out, lr)

        d_out = self.relu1.backward(d_out)
        d_out = self.conv1.backward(d_out, lr)

    def save(self, path):
        params = {
            'conv1_w': self.conv1.weights, 'conv1_b': self.conv1.biases,
            'conv2_w': self.conv2.weights, 'conv2_b': self.conv2.biases,
            'conv3_w': self.conv3.weights, 'conv3_b': self.conv3.biases,
            'dense1_w': self.dense1.weights, 'dense1_b': self.dense1.biases,
            'dense2_w': self.dense2.weights, 'dense2_b': self.dense2.biases
        }
        with open(path, 'wb') as f:
            pickle.dump(params, f)

    def load(self, path):
        with open(path, 'rb') as f:
            params = pickle.load(f)
        self.conv1.weights = params['conv1_w']
        self.conv1.biases = params['conv1_b']
        self.conv2.weights = params['conv2_w']
        self.conv2.biases = params['conv2_b']
        self.conv3.weights = params['conv3_w']
        self.conv3.biases = params['conv3_b']
        self.dense1.weights = params['dense1_w']
        self.dense1.biases = params['dense1_b']
        self.dense2.weights = params['dense2_w']
        self.dense2.biases = params['dense2_b']

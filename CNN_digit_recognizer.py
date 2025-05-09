import os
import sys
import numpy as np
from PIL import Image
from simple_cnn import SimpleCNN
import pickle

# Configuration
IMG_SIZE = 28
NUM_CLASSES = 10
DATA_DIR = "./data"
MODEL_FILE = "trained_model.pkl"
EPOCHS = 5
LR = 0.01
BATCH_SIZE = 10

def load_data(data_dir):
    X = []
    y = []
    for label in range(NUM_CLASSES):
        folder = os.path.join(data_dir, str(label))
        if not os.path.isdir(folder):
            continue
        for fname in os.listdir(folder):
            if fname.endswith(".jpg"):
                img_path = os.path.join(folder, fname)
                img = Image.open(img_path).convert('L')
                img = img.resize((IMG_SIZE, IMG_SIZE))
                arr = np.array(img) / 255.0
                X.append(arr)
                y.append(label)
    X = np.array(X).reshape(-1, 1, IMG_SIZE, IMG_SIZE)
    y = np.array(y)
    return X, y

def one_hot(y, num_classes=10):
    return np.eye(num_classes)[y]

def cross_entropy_loss(pred, label):
    loss = -np.sum(label * np.log(pred + 1e-8)) / pred.shape[0]
    return loss

def accuracy(pred, label):
    return np.mean(np.argmax(pred, axis=1) == np.argmax(label, axis=1))

def train():
    print("Loading training data...")
    X, y = load_data(DATA_DIR)
    y_onehot = one_hot(y)

    model = SimpleCNN()

    for epoch in range(EPOCHS):
        permutation = np.random.permutation(len(X))
        X_shuffled, y_shuffled = X[permutation], y_onehot[permutation]

        total_loss = 0
        for i in range(0, len(X_shuffled), BATCH_SIZE):
            x_batch = X_shuffled[i:i+BATCH_SIZE]
            y_batch = y_shuffled[i:i+BATCH_SIZE]

            output = model.forward(x_batch)
            loss = cross_entropy_loss(output, y_batch)
            total_loss += loss

            d_out = (output - y_batch) / BATCH_SIZE
            model.backward(d_out, LR)

        acc = accuracy(model.forward(X), y_onehot)
        print(f"Epoch {epoch+1}/{EPOCHS} - Loss: {total_loss:.4f}, Accuracy: {acc:.4f}")

    model.save(MODEL_FILE)
    print(f"Training completed. Model saved to '{MODEL_FILE}'.")

def infer(image_path):
    print(f"Loading model from '{MODEL_FILE}'...")
    model = SimpleCNN()
    model.load(MODEL_FILE)

    img = Image.open(image_path).convert('L')
    img = img.resize((IMG_SIZE, IMG_SIZE))
    arr = np.array(img) / 255.0
    x = arr.reshape(1, 1, IMG_SIZE, IMG_SIZE)

    output = model.forward(x)
    pred = np.argmax(output)
    print(f"Predicted class: {pred}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage:")
        print("  python run_cnn.py train")
        print("  python run_cnn.py infer path_to_image.jpg")
        sys.exit(1)

    if sys.argv[1] == "train":
        train()
    elif sys.argv[1] == "infer":
        if len(sys.argv) != 3:
            print("Usage: python run_cnn.py infer path_to_image.jpg")
            sys.exit(1)
        infer(sys.argv[2])
    else:
        print(f"Unknown command: {sys.argv[1]}")
        print("Use 'train' or 'infer'.")

import os
os.environ["OMP_NUM_THREADS"] = "10"
import sys
import numpy as np
from PIL import Image
from simple_cnn import SimpleCNN
import pickle
import conv2d

# Configuration
IMG_SIZE = 10
NUM_CLASSES = 10
DATA_DIR = "../Generate_Modified_Images/Dataset_10x10/"
MODEL_FILE = "trained_model.pkl"
EPOCHS = 1
LR = 0.01
BATCH_SIZE = 1

def load_data(data_dir):
    """
    Loads image data and labels from the specified directory.

    Args:
        data_dir (str): Path to the dataset directory. Expects subfolders named 0-9, each containing .jpg images.

    Returns:
        tuple: (X, y) where X is a numpy array of shape (num_samples, 1, IMG_SIZE, IMG_SIZE) and y is a numpy array of labels.
    """
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
    
    X = X[:len(X)//4]
    y = y[:len(y)//4]
    # X = X[0]
    # y = y[0]
    X = np.array(X).reshape(-1, 1, IMG_SIZE, IMG_SIZE)
    y = np.array(y)
    return X, y

def one_hot(y, num_classes=10):
    """
    Converts integer labels to one-hot encoded vectors.

    Args:
        y (array-like): Array of integer labels.
        num_classes (int): Number of classes for one-hot encoding.

    Returns:
        np.ndarray: One-hot encoded label matrix.
    """
    return np.eye(num_classes)[y]

def cross_entropy_loss(pred, label):
    """
    Computes the cross-entropy loss between predictions and true labels.

    Args:
        pred (np.ndarray): Predicted probabilities (batch_size, num_classes).
        label (np.ndarray): One-hot encoded true labels (batch_size, num_classes).

    Returns:
        float: Cross-entropy loss value.
    """
    loss = -np.sum(label * np.log(pred + 1e-8)) / pred.shape[0]
    return loss

def accuracy(pred, label):
    """
    Calculates the classification accuracy.

    Args:
        pred (np.ndarray): Predicted probabilities (batch_size, num_classes).
        label (np.ndarray): One-hot encoded true labels (batch_size, num_classes).

    Returns:
        float: Accuracy as a fraction of correct predictions.
    """
    return np.mean(np.argmax(pred, axis=1) == np.argmax(label, axis=1))

def train():
    """
    Trains the SimpleCNN model on the dataset.

    Loads data, trains for a specified number of epochs, prints loss and accuracy, and saves the trained model.
    """
    print("Loading training data...")
    X, y = load_data(DATA_DIR)
    y_onehot = one_hot(y)

    model = SimpleCNN()

    print("Training model...")
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
    """
    Loads a trained model and predicts the class of a given image.

    Args:
        image_path (str): Path to the image file to be classified.
    """
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
        print("  python CNN_digit_recognizer.py train")
        print("  python CNN_digit_recognizer.py infer path_to_image.jpg")
        sys.exit(1)

    if sys.argv[1] == "train":
        conv2d.MODE = "train"
        train()
    elif sys.argv[1] == "infer":
        if len(sys.argv) != 3:
            print("Usage: python CNN_digit_recognizer.py infer path_to_image.jpg")
            sys.exit(1)
        conv2d.MODE = "infer"
        infer(sys.argv[2])
    else:
        print(f"Unknown command: {sys.argv[1]}")
        print("Use 'train' or 'infer'.")

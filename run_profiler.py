import cProfile
import pstats
import sys

# Set the path to your image here
IMAGE_PATH = "trainingSet/trainingSet/5/img_8.jpg"

# Import your model script (assuming infer is a top-level function)
from CNN_digit_recognizer import *

def profile_infer():
    cProfile.runctx(
        'infer(IMAGE_PATH)',
        globals(),
        locals(),
        filename='infer_profile.prof'
    )

if __name__ == "__main__":
    profile_infer()
    print("Profiling complete. Use `snakeviz infer_profile.prof` to view.")

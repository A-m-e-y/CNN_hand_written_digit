import cProfile
import pstats
import sys

# Set the path to your image here
IMAGE_PATH = "../Generate_Modified_Images/Dataset_24x24/0/0.jpg"

# Import your model script (assuming infer is a top-level function)
from CNN_digit_recognizer import *

def profile_infer():
    """
    Profiles the 'infer' function using cProfile.

    Runs inference on the specified IMAGE_PATH and saves profiling results to 'infer_profile.prof'.
    """
    cProfile.runctx(
        'infer(IMAGE_PATH)',
        globals(),
        locals(),
        filename='infer_profile.prof'
    )

if __name__ == "__main__":
    profile_infer()
    stats = pstats.Stats('infer_profile.prof')
    stats.strip_dirs().sort_stats('cumtime').print_stats(20)
    print("Profiling complete. Use `snakeviz infer_profile.prof` to view.")

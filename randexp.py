#!/bin/python
# Generate a random integer drawn from an exponential distribution.
import random
mean=100.0
n = random.expovariate(1.0/mean)
print int(n)
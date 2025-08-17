import numpy as np
import math
import sys

#  Base class for modular reduction algorithms
class ModularReduction:
  def __init__(self, modulus):
          self.modulus = modulus

  def reduce(self, mult):
        raise NotImplementedError("Subclasses must implement the reduce method.")

  @classmethod
  def available_algorithms(cls):
        return {subclass.__name__.lower().replace("reduction", ""): subclass
                for subclass in cls.__subclasses__()}

  def __repr__(self):
        return f"{self.__class__.__name__}(modulus={self.modulus})"

class SchoolbookReduction(ModularReduction):
    def __init__(self, modulus):
      super().__init__(modulus)

    def reduce(self, mult):
        return mult % self.modulus

class BarrettReduction(ModularReduction):
  def __init__(self, modulus):
    super().__init__(modulus)
    self.k = self.modulus.bit_length()
    self.mu = np.object_((1 << 2 * self.k) // self.modulus)

  def reduce(self, mult):
    assert np.all(mult <= self.modulus**2)
    approximated_quotient = np.multiply(mult, self.mu, dtype=np.object_) >> np.multiply(2, self.k, dtype=np.object_)
    remainder = mult - np.multiply(approximated_quotient,self.modulus, dtype=np.object_)

    # This will do a bitmask over the entire np.array() and will thus avoid any branching
    remainder -= np.multiply(self.modulus, (remainder >= self.modulus), dtype=np.object_)
    return remainder


class MontgomeryReduction(ModularReduction):
    def __init__(self, modulus):
      super().__init__(modulus)
      self.modulus = np.object_(self.modulus)
      self.radix = np.object_(1 << int(self.modulus).bit_length()) #R = (2 ^ n)
      assert np.gcd(self.radix, self.modulus, dtype=np.object_) == 1, "The modulus and the radix are not coprime!" # for the modular inverse to exist
      self.inv_radix = np.object_(pow(self.radix, -1, self.modulus))
      self.n_prime = np.object_(-pow(self.modulus, -1, self.radix))

    def to_montgomery(self, x):
      return np.object_(np.object_(x) * self.radix % self.modulus)

    def from_montgomery(self, x):
      return np.object_((np.object_(x) * self.inv_radix) % self.modulus)

    def reduce(self, T):
      m = np.object_((T & (self.radix - 1)) * self.n_prime & (self.radix - 1))
      t = np.object_((T + m * self.modulus) >> self.modulus.bit_length())
      t = np.where(t >= self.modulus, t - self.modulus, t)
      return t




# General Mersenne Reduction
class ShiftAddReduction(ModularReduction):
    # If we use the Mersenne modulus property:
    # m = 2^k - n => 2^k congr. n (mod 2^k - n)
    # we can split our input number into k-bit chunks and by
    # folding the chunks into the range [0, M)
    # the remainder is computed by summing up the folded k-bit chunks
    def __init__(self, modulus):
        super().__init__(modulus)
        self.k = self.modulus.bit_length()
        self.k_2 = np.object_(1 << self.k)  # 2^k
        self.mask = np.object_(self.k_2 - 1)
        self.coeff = np.object_(self.k_2 % self.modulus)  # 2^k % modulus to get n.


    def reduce(self, mult):
      print(f"bitlength: {self.k}")
      print(f"correction: {self.coeff}")
      remainder = np.object_(mult.copy())
      while np.any(remainder >= self.modulus):
        # mask gets least k bits, r >> k removes those k bits
        hi = np.object_(remainder >> self.k)
        lo = np.object_(remainder & self.mask)
        # Fold anything above 2^k using n
        remainder = np.object_(self.coeff * hi  + lo)
      if np.any(remainder >= self.modulus):
         print("t")
         remainder[remainder>= self.modulus] -= self.modulus
      return remainder


ALGORITHMS = ModularReduction.available_algorithms()
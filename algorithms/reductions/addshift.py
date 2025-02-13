# Add&Shift algorithm for modular multiplication
import time 
modulus = 17

def addshift(a, b):
  start_time = time.perf_counter()
  tmp = int(b, 2)
  result = 0
  a = a[::-1]

  for i in range(0, len(a)):
    if a[i] == "1":
      result = result + (tmp << i)
    elif a[i] == "0":
      result = result + (0 << i)
    tmp = int(b, 2)
    i+=1
  # print("multiplication result: ", result)

  result = result % modulus
  print(result)
  end_time = time.perf_counter()
  return result, end_time - start_time


def main():
    binary_pairs = [] 
    with open("addshift.txt", "r") as file:
        for line in file:
            binary_pairs.append(line.strip().split())

    print("Doing modular reduction with plain Shift & Add reduction:")

    for (a, b) in binary_pairs:
      print("-------------------------------------------------")
      res, elapsed_time = addshift(a, b)

      print(f"Compute {int(a, 2)} * {int(b, 2)} % {modulus} = {res} ({bin(res)})")
      print(f"elapsed time: {elapsed_time * 1000} (ms)")
      # print("-------------------------------------------------")
           


if __name__ == "__main__":
    main()

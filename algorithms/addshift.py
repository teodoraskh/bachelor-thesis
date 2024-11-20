# Add&Shift algorithm for modular multiplication

modulus = 17

def addshift(a, b):
  print("\n\n\n\n")
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
  print(result)

  return result % modulus


def main():
    binary_pairs = [] 
    with open("addshift.txt", "r") as file:
        for line in file:
            binary_pairs.append(line.strip().split())

    for (a, b) in binary_pairs:
      res = addshift(a, b)
      print(bin(res))
      print(res)
           


if __name__ == "__main__":
    main()

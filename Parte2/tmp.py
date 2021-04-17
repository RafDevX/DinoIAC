def divint(a, b):
	q = 0

	while a >= 0:
		a = a - b
		q = q + 1

	return q - 1, a + b

def convert(b):
	lst = ()
	for _ in range(6):
		b, e = divint(b, 10)
		lst = (e,) + lst
	
	return lst

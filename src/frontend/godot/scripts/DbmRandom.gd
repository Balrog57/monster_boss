class_name DbmRandom
extends RefCounted
## DBMRandom de l'APK (DBMGameModel/DBMRandom.cs) : copie de System.Random (generateur soustractif de Knuth). Sert a RandomProvider.Shuffle ;
## le tutoriel fixe la graine a 2832 (GameBoardExtensions.cs:25), donc l'ordre des paquets est le meme a chaque tutoriel.

const MBIG := 2147483647
const MSEED := 161803398

var _seed_array: Array[int] = []
var _inext := 0
var _inextp := 21
var samples := 0 # NumberOfSamples

func _init(seed_value: int = 1) -> void:
	_seed_array.resize(56)
	_seed_array.fill(0)
	var num := MSEED - (MBIG if seed_value == -2147483648 else absi(seed_value))
	_seed_array[55] = num
	var num2 := 1
	for i in range(1, 55):
		var num3 := (21 * i) % 55
		_seed_array[num3] = num2
		num2 = num - num2
		if num2 < 0:
			num2 += MBIG
		num = _seed_array[num3]
	for _j in range(1, 5):
		for k in range(1, 56):
			_seed_array[k] -= _seed_array[1 + (k + 30) % 55]
			if _seed_array[k] < 0:
				_seed_array[k] += MBIG

func next_raw() -> int:
	samples += 1
	var a := _inext + 1
	var b := _inextp + 1
	if a >= 56:
		a = 1
	if b >= 56:
		b = 1
	var v := _seed_array[a] - _seed_array[b]
	if v == MBIG:
		v -= 1
	if v < 0:
		v += MBIG
	_seed_array[a] = v
	_inext = a
	_inextp = b
	return v

## Next(maxValue) : entier dans [0, max_value).
func next_int(max_value: int) -> int:
	return int(float(next_raw()) * 4.656612875245797e-10 * float(max_value))

## RandomProvider.Shuffle (RandomProvider.cs:43-62) : Fisher-Yates depuis la fin, Next(index + 1).
func shuffle(source: Array) -> Array:
	var a := source.duplicate()
	for i in range(a.size() - 1, 0, -1):
		var j := next_int(i + 1)
		var t = a[i]
		a[i] = a[j]
		a[j] = t
	return a

class_name DbmRandom
extends RefCounted
## DBMRandom de l'APK (DBMGameModel/DBMRandom.cs) : copie de System.Random (generateur soustractif de Knuth). Sert a RandomProvider.Shuffle ;
## le tutoriel fixe la graine a 2832 (GameBoardExtensions.cs:25), donc l'ordre des paquets est le meme a chaque tutoriel.
## L'etat vit dans un Dictionary (`st` : a = SeedArray, i = inext, j = inextp, n = NumberOfSamples) pour tenir dans G["dbm"] :
## une copie profonde de G (sondes de legal_moves) copie aussi le generateur, donc une sonde ne consomme jamais le tirage de la partie.

const MBIG := 2147483647
const MSEED := 161803398

var st: Dictionary = {}

## Arithmetique int32 de C# (non verifiee, avec bouclage) : pour une graine > MSEED, `num` est negatif et les soustractions debordent ; sans bouclage les valeurs sortent de
## [0, MBIG) et Next(max) rend un indice hors tableau (RandomProvider.SetNewRandomSeed tire la graine dans tout l'intervalle).
static func _i32(v: int) -> int:
	return ((v + 2147483648) & 0xFFFFFFFF) - 2147483648

func _init(seed_value: int = 1) -> void:
	var sa: Array = []
	sa.resize(56)
	sa.fill(0)
	var num := MSEED - (MBIG if seed_value == -2147483648 else absi(seed_value))
	sa[55] = num
	var num2 := 1
	for i in range(1, 55):
		var num3 := (21 * i) % 55
		sa[num3] = num2
		num2 = _i32(num - num2)
		if num2 < 0:
			num2 += MBIG
		num = sa[num3]
	for _j in range(1, 5):
		for k in range(1, 56):
			sa[k] = _i32(sa[k] - sa[1 + (k + 30) % 55])
			if sa[k] < 0:
				sa[k] += MBIG
	st = {"a": sa, "i": 0, "j": 21, "n": 0}

## Generateur qui continue l'etat `state` (G["dbm"], partage par reference : les tirages le font avancer).
static func of(state: Dictionary) -> DbmRandom:
	var r := DbmRandom.new(1)
	r.st = state
	return r

## NumberOfSamples : nombre d'appels a Next() depuis la graine.
func samples() -> int:
	return int(st["n"])

func next_raw() -> int:
	st["n"] = int(st["n"]) + 1
	var sa: Array = st["a"]
	var a := int(st["i"]) + 1
	var b := int(st["j"]) + 1
	if a >= 56:
		a = 1
	if b >= 56:
		b = 1
	var v := int(sa[a]) - int(sa[b])
	if v == MBIG:
		v -= 1
	if v < 0:
		v += MBIG
	sa[a] = v
	st["i"] = a
	st["j"] = b
	return v

## Next(maxValue) : entier dans [0, max_value).
func next_int(max_value: int) -> int:
	return int(float(next_raw()) * 4.656612875245797e-10 * float(max_value))

## RandomProvider.Shuffle (RandomProvider.cs:43-62) : Fisher-Yates depuis la fin, Next(index + 1). Rend le tableau melange ; l'iterateur de l'APK
## rend ses elements du dernier au premier, donc le sommet d'une pioche (tete de la Queue) est le DERNIER element (pop_back).
func shuffle(source: Array) -> Array:
	var out := take(source, source.size())
	out.reverse()
	return out

## Shuffle().Take(k) : l'iterateur est paresseux, seuls les k premiers elements rendus (a[n-1], a[n-2]...) sont tires, soit min(k, n - 1) appels a Next.
## Rend ces elements dans l'ordre ou l'APK les rend.
func take(source: Array, k: int) -> Array:
	var a := source.duplicate()
	var out: Array = []
	var index := a.size() - 1
	while index > 0 and out.size() < k:
		var j := next_int(index + 1)
		var t = a[index]
		a[index] = a[j]
		a[j] = t
		out.append(a[index])
		index -= 1
	if index == 0 and out.size() < k and a.size() > 0:
		out.append(a[0])
	return out

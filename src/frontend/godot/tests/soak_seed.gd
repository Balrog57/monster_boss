extends RefCounted
## Graine toutes les sources d'alea d'une partie de soak (goldens reproductibles) : melanges CardDB, Match.rng,
## TnlAbilities, et RNG global (randi / Array.shuffle). A appeler apres add_child(m) (Match._ready() randomise) et avant new_match.
static func seed_game(m: Node, s: int) -> void:
	seed(s)
	CardDB._rng.seed = s
	m.rng.seed = s
	TnlAbilities._rng.seed = s
	TnlAbilities._rng_ready = true

## Fin des soaks : on rend l'alea aux tests suivants.
static func unseed() -> void:
	randomize()
	CardDB._rng.randomize()
	TnlAbilities._rng.randomize()

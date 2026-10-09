// stack.js - Spell and ability stack with Last-In-First-Out resolution.
//
// The stack is a list of effects on G.stack. Each effect has:
//   { id, type: 'spell'|'ability', playerId, card, target, resolved: boolean }
// Players can respond to the top effect with their own spell/ability until everyone passes.
// Then the stack resolves from top to bottom.

export function emptyStack() {
  return [];
}

export function pushEffect(G, playerId, type, card, target = null) {
  G.stack.push({
    id: `${type}-${card?.id}-${Date.now()}-${Math.random().toString(36).slice(2)}`,
    type,
    playerId,
    card,
    target,
    resolved: false
  });
  G.stackPassed = {};
}

export function topEffect(G) {
  return G.stack.length > 0 ? G.stack[G.stack.length - 1] : null;
}

export function allPassed(G, players) {
  const active = Object.keys(players).filter(pid => !players[pid].eliminated).map(String);
  if (active.length === 0) return true;
  return active.every(pid => G.stackPassed[pid]);
}

export function resolveStack(G, ctx, resolver) {
  // resolver(effect) applies the effect to G and returns true if applied.
  while (G.stack.length > 0) {
    const effect = G.stack.pop();
    if (effect.resolved) continue;
    resolver(effect, G, ctx);
    effect.resolved = true;
  }
  G.stackPassed = {};
}

export function clearStack(G) {
  G.stack = emptyStack();
  G.stackPassed = {};
}

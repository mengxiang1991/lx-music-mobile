export enum PlaybackMode {
  Sequential,
  RepeatQueue,
  RepeatTrack,
  Shuffle
}

export function shuffleOrder(length: number, active: number): number[] {
  if (active < 0 || active >= length) return [];
  const rest: number[] = [];
  for (let i = 0; i < length; i++) {
    if (i !== active) rest.push(i);
  }
  for (let i = rest.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    const item = rest[i];
    rest[i] = rest[j];
    rest[j] = item;
  }
  return [active, ...rest];
}

export function nextIndex(mode: PlaybackMode, order: number[], length: number, active: number,
  step: number, finished: boolean = false): number {
  if (active < 0 || active >= length) return -1;
  if (finished && mode === PlaybackMode.RepeatTrack) return active;
  if (mode === PlaybackMode.Shuffle) {
    const position = order.indexOf(active);
    return position < 0 ? -1 : (order[position + step] ?? -1);
  }
  if (mode === PlaybackMode.RepeatQueue) return (active + step + length) % length;
  const target = active + step;
  return target >= 0 && target < length ? target : -1;
}

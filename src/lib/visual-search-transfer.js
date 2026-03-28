let pendingVisualSearchPayload = null;

export function setPendingVisualSearchFile(file) {
  if (!(file instanceof File)) {
    pendingVisualSearchPayload = null;
    return;
  }

  pendingVisualSearchPayload = {
    file,
    name: String(file.name || "").trim(),
    timestamp: Date.now(),
  };
}

export function consumePendingVisualSearchFile() {
  const nextPayload = pendingVisualSearchPayload;
  pendingVisualSearchPayload = null;
  return nextPayload;
}

export function hasPendingVisualSearchFile() {
  return Boolean(pendingVisualSearchPayload?.file);
}

export async function requestJson(url, options = {}) {
  const config = { ...options };
  config.headers = { ...(options.headers || {}) };

  if (
    config.body &&
    !(config.body instanceof FormData) &&
    !config.headers["Content-Type"]
  ) {
    config.headers["Content-Type"] = "application/json";
  }

  const response = await fetch(url, config);
  let data = {};

  try {
    data = await response.json();
  } catch (error) {
    console.error(error);
  }

  return { response, data };
}

export async function fetchCurrentUserOptional() {
  try {
    const { response, data } = await requestJson("/api/me");
    if (!response.ok || !data.ok || !data.user) {
      return null;
    }

    return data.user;
  } catch (error) {
    console.error(error);
    return null;
  }
}

export async function fetchProtectedCollection(url) {
  try {
    const { response, data } = await requestJson(url);
    if (!response.ok || !data.ok) {
      return [];
    }

    return Array.isArray(data.items) ? data.items : [];
  } catch (error) {
    console.error(error);
    return [];
  }
}

export function resolveApiMessage(data, fallbackMessage) {
  return (
    data?.errors?.join(" ") ||
    data?.message ||
    fallbackMessage
  );
}

export async function uploadImages(files = []) {
  const uploadData = new FormData();
  files.forEach((file) => {
    uploadData.append("images", file);
  });

  const { response, data } = await requestJson("/api/uploads", {
    method: "POST",
    body: uploadData,
  });

  if (!response.ok || !data?.ok || !Array.isArray(data.paths) || data.paths.length === 0) {
    return {
      ok: false,
      paths: [],
      message: resolveApiMessage(data, "Fotot nuk u ngarkuan."),
    };
  }

  return {
    ok: true,
    paths: data.paths,
    message: data.message || "Fotot u ngarkuan me sukses.",
  };
}

export async function uploadProfilePhoto(file) {
  const uploadData = new FormData();
  uploadData.append("image", file);

  const { response, data } = await requestJson("/api/profile/photo", {
    method: "POST",
    body: uploadData,
  });

  if (!response.ok || !data?.ok || !data.path) {
    return {
      ok: false,
      path: "",
      message: resolveApiMessage(data, "Fotoja e profilit nuk u ngarkua."),
    };
  }

  return {
    ok: true,
    path: String(data.path).trim(),
    message: data.message || "Fotoja e profilit u ngarkua me sukses.",
  };
}

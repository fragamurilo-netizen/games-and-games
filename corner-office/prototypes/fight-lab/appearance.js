/* Game Bible §§5,15. Identity normalization is presentation-only. */
(function (root, factory) {
  const api = factory();
  if (typeof module === "object") module.exports = api;
  else root.FightAppearance = api;
})(typeof window === "object" ? window : this, () => {
  const copy = (x) => JSON.parse(JSON.stringify(x));
  function resolve(f, canon, generate) {
    const explicit =
      f.sex === 1 || f.sex === "f" || f.sex === "female"
        ? "f"
        : f.sex === 0 || f.sex === "m" || f.sex === "male"
          ? "m"
          : null;
    const indexed = Number.isInteger(f.appearance_index)
      ? canon[f.appearance_index]
      : null;
    let appearance = f.appearance?.head ? f.appearance : indexed;
    if (!appearance || (explicit && appearance.sex !== explicit)) {
      appearance =
        generate && f.appearance?.seed != null
          ? generate(
              f.appearance.seed,
              f.appearance.pop || "misto",
              explicit || "m",
            )
          : canon.find((x) => x.sex === (explicit || "m"));
    }
    const out = copy(appearance);
    out.sex = explicit || out.sex;
    out.name = f.name || out.name;
    out.body = { ...out.body, ...(f.appearance?.body || {}) };
    if (Number.isFinite(f.appearance?.age)) out.age = f.appearance.age;
    if (out.sex === "f")
      out.body = { shoulders: 0.35, hips: 0.65, waist: 0.35, ...out.body };
    out.marks = (out.marks || []).filter(
      (x) => !["brinco", "argola", "piercing", "nose_ring"].includes(x),
    );
    return out;
  }
  return { resolve };
});

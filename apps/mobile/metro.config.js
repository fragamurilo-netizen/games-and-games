// Expo detecta monorepos automaticamente (workspaces npm).
const { getDefaultConfig } = require("expo/metro-config")

const config = getDefaultConfig(__dirname)
config.resolver.assetExts.push("wasm")
// SQLite web precisa de SharedArrayBuffer. Sem alterar a aplicação Android.
config.server.enhanceMiddleware = middleware => (req, res, next) => {
  res.setHeader("Cross-Origin-Opener-Policy", "same-origin")
  res.setHeader("Cross-Origin-Embedder-Policy", "credentialless")
  return middleware(req, res, next)
}
module.exports = config

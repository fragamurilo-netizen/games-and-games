// Expo detecta monorepos automaticamente (workspaces npm).
const { getDefaultConfig } = require("expo/metro-config")

module.exports = getDefaultConfig(__dirname)

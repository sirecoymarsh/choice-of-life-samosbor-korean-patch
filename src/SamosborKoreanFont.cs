using System;
using System.Collections.Generic;
using System.IO;
using System.Reflection;
using BepInEx;
using TMPro;
using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.TextCore.LowLevel;

namespace SamosborKorean
{
    [BepInPlugin(PluginGuid, PluginName, PluginVersion)]
    public sealed class KoreanFontPlugin : BaseUnityPlugin
    {
        public const string PluginGuid = "local.samosbor.koreanfont";
        public const string PluginName = "Samosbor Korean Font";
        public const string PluginVersion = "1.0.0";

        private TMP_FontAsset koreanFont;
        private string pluginDirectory;

        private void Awake()
        {
            pluginDirectory = Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location);
            SceneManager.sceneLoaded += OnSceneLoaded;

            try
            {
                LoadKoreanFont();
                ApplyFallbacks();
                InvokeRepeating("ApplyFallbacks", 2.0f, 5.0f);
            }
            catch (Exception exception)
            {
                Logger.LogError("Korean font initialization failed: " + exception);
            }
        }

        private void OnDestroy()
        {
            SceneManager.sceneLoaded -= OnSceneLoaded;
        }

        private void OnSceneLoaded(Scene scene, LoadSceneMode mode)
        {
            ApplyFallbacks();
        }

        private void LoadKoreanFont()
        {
            string fontPath = Path.Combine(pluginDirectory, "NotoSansKR-VF.ttf");
            if (!File.Exists(fontPath))
            {
                throw new FileNotFoundException("Bundled Korean font is missing.", fontPath);
            }

            koreanFont = TMP_FontAsset.CreateFontAsset(
                fontPath,
                0,
                64,
                8,
                GlyphRenderMode.SDFAA,
                2048,
                2048
            );
            if (koreanFont == null)
            {
                throw new InvalidOperationException("TMP_FontAsset.CreateFontAsset returned null.");
            }

            koreanFont.name = "Samosbor Korean - Noto Sans KR";
            koreanFont.atlasPopulationMode = AtlasPopulationMode.Dynamic;
            koreanFont.isMultiAtlasTexturesEnabled = true;

            string charsetPath = Path.Combine(pluginDirectory, "hangul_charset.txt");
            if (File.Exists(charsetPath))
            {
                string charset = File.ReadAllText(charsetPath);
                string missing;
                if (!koreanFont.TryAddCharacters(charset, out missing, true))
                {
                    Logger.LogWarning("Some Korean patch characters could not be added: " + missing);
                }
            }

            List<TMP_FontAsset> globalFallbacks = TMP_Settings.fallbackFontAssets;
            if (globalFallbacks == null)
            {
                globalFallbacks = new List<TMP_FontAsset>();
                TMP_Settings.fallbackFontAssets = globalFallbacks;
            }
            if (!globalFallbacks.Contains(koreanFont))
            {
                globalFallbacks.Add(koreanFont);
            }

            Logger.LogInfo(
                "Loaded Korean font. Sample glyphs available: " +
                koreanFont.HasCharacters("한글")
            );
        }

        private void ApplyFallbacks()
        {
            if (koreanFont == null)
            {
                return;
            }

            TMP_Text[] texts = Resources.FindObjectsOfTypeAll<TMP_Text>();
            int updated = 0;
            for (int i = 0; i < texts.Length; i++)
            {
                TMP_Text text = texts[i];
                if (text == null || text.font == null || text.font == koreanFont)
                {
                    continue;
                }

                List<TMP_FontAsset> fallbacks = text.font.fallbackFontAssetTable;
                if (fallbacks == null)
                {
                    fallbacks = new List<TMP_FontAsset>();
                    text.font.fallbackFontAssetTable = fallbacks;
                }
                if (!fallbacks.Contains(koreanFont))
                {
                    fallbacks.Add(koreanFont);
                    updated++;
                }
                text.SetAllDirty();
            }

            if (updated > 0)
            {
                Logger.LogInfo("Attached Korean fallback to " + updated + " TMP font assets.");
            }
        }
    }
}

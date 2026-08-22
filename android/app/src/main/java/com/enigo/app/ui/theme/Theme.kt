@file:OptIn(androidx.compose.ui.text.ExperimentalTextApi::class)

package com.enigo.app.ui.theme

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontVariation
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.sp
import com.enigo.app.R

// Design tokens transcribed from design_handoff_enigo/README.md — same
// source of truth as the iOS DesignSystem/Theme.swift. Dark is gold-on-navy
// (default), light is navy-on-ivory; gold recedes to accents only in light.
object EnigoColor {
    fun background(dark: Boolean) = if (dark) Color(0xFF0B1D3A) else Color(0xFFEFE9D8)
    fun pageSurround(dark: Boolean) = if (dark) Color(0xFF08152B) else Color(0xFFDED5BD)
    fun sheetBase(dark: Boolean) = if (dark) Color(0xFF0F2547) else Color(0xFFEFE9D8)
    fun dominant(dark: Boolean) = if (dark) Color(0xFFD4AF37) else Color(0xFF0B1D3A)
    fun accent(dark: Boolean) = if (dark) Color(0xFFD4AF37) else Color(0xFFA8861C)
    fun body(dark: Boolean) = if (dark) Color(0xFFE8D9A8) else Color(0xFF0B1D3A)
    fun danger(dark: Boolean) = if (dark) Color(0xFFE4A08C) else Color(0xFF9E3A1C)
    fun primaryFill(dark: Boolean) = dominant(dark)
    fun primaryLabel(dark: Boolean) = if (dark) Color(0xFF0B1D3A) else Color(0xFFEFE9D8)
    fun fgAlpha(dark: Boolean, alpha: Float) = body(dark).copy(alpha = alpha)
    fun goldAlpha(dark: Boolean, alpha: Float) = accent(dark).copy(alpha = alpha)
}

// Both fonts ship as single variable-font files (per Google Fonts), so a
// specific weight is selected via the `wght` axis rather than a distinct
// PostScript name — mirrors the iOS variableFont() helper.
object EnigoFont {
    val screenTitleSize = 31.sp
    val questionTextSize = 28.sp
    val matchUsernameSize = 34.sp
    val answerOptionSize = 17.sp
    val chipLabelSize = 15.sp
    val bodySize = 14.5.sp
    val chatMessageSize = 15.sp
    val eyebrowSize = 11.sp
    val metaSize = 12.sp

    fun frauncesFamily(weight: Int) = FontFamily(
        Font(R.font.fraunces, weight = FontWeight(weight), variationSettings = FontVariation.Settings(FontVariation.weight(weight)))
    )
    fun interFamily(weight: Int) = FontFamily(
        Font(R.font.inter, weight = FontWeight(weight), variationSettings = FontVariation.Settings(FontVariation.weight(weight)))
    )
}

object EnigoRadius {
    val control = 14
    val input = 16
    val card = 18
    val photoWell = 22
    val sheetTop = 26
    val pill = 99
}

object EnigoSpacing {
    val screenHorizontal = 28
    val listHorizontal = 22
    val stackGap = 20
    val tightGap = 9
}

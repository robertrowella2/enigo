package com.enigo.app.ui.theme

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/** Screen scaffold: theme background + horizontal padding, per the doc's spacing tokens. */
@Composable
fun EnigoScreen(
    topPadding: Int = 32,
    content: @Composable ColumnScope.() -> Unit
) {
    val dark = isSystemInDarkTheme()
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(EnigoColor.background(dark))
            .verticalScroll(rememberScrollState())
            .padding(horizontal = EnigoSpacing.screenHorizontal.dp)
            .padding(top = topPadding.dp, bottom = 40.dp),
        verticalArrangement = Arrangement.spacedBy(EnigoSpacing.stackGap.dp)
    ) {
        content()
    }
}

@Composable
fun PrimaryButton(
    title: String,
    modifier: Modifier = Modifier,
    disabled: Boolean = false,
    isLoading: Boolean = false,
    onClick: () -> Unit
) {
    val dark = isSystemInDarkTheme()
    Button(
        onClick = onClick,
        enabled = !disabled && !isLoading,
        shape = RoundedCornerShape(EnigoRadius.control.dp),
        colors = ButtonDefaults.buttonColors(
            containerColor = if (disabled) EnigoColor.fgAlpha(dark, 0.12f) else EnigoColor.primaryFill(dark),
            contentColor = if (disabled) EnigoColor.fgAlpha(dark, 0.4f) else EnigoColor.primaryLabel(dark),
            disabledContainerColor = EnigoColor.fgAlpha(dark, 0.12f),
            disabledContentColor = EnigoColor.fgAlpha(dark, 0.4f)
        ),
        modifier = modifier.fillMaxWidth().height(52.dp)
    ) {
        if (isLoading) {
            CircularProgressIndicator(modifier = Modifier.height(20.dp), color = EnigoColor.primaryLabel(dark))
        } else {
            Text(title, fontFamily = EnigoFont.interFamily(600), fontSize = EnigoFont.chipLabelSize)
        }
    }
}

@Composable
fun SecondaryLink(title: String, onClick: () -> Unit) {
    val dark = isSystemInDarkTheme()
    TextButton(onClick = onClick, modifier = Modifier.fillMaxWidth()) {
        Text(title, color = EnigoColor.fgAlpha(dark, 0.6f), fontFamily = EnigoFont.interFamily(400), fontSize = EnigoFont.bodySize)
    }
}

@Composable
fun ScreenTitle(text: String) {
    val dark = isSystemInDarkTheme()
    Text(
        text,
        color = EnigoColor.dominant(dark),
        fontFamily = EnigoFont.frauncesFamily(600),
        fontSize = EnigoFont.screenTitleSize,
        style = TextStyle(lineHeight = EnigoFont.screenTitleSize * 1.14f)
    )
}

@Composable
fun Eyebrow(text: String) {
    val dark = isSystemInDarkTheme()
    Text(
        text.uppercase(),
        color = EnigoColor.fgAlpha(dark, 0.4f),
        fontFamily = EnigoFont.interFamily(500),
        fontSize = EnigoFont.eyebrowSize,
        letterSpacing = 2.sp
    )
}

@Composable
fun SelectableRow(text: String, selected: Boolean, onClick: () -> Unit) {
    val dark = isSystemInDarkTheme()
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(EnigoRadius.control.dp))
            .background(if (selected) EnigoColor.goldAlpha(dark, 0.12f) else EnigoColor.fgAlpha(dark, 0.05f))
            .border(1.dp, if (selected) EnigoColor.accent(dark).copy(alpha = 0.55f) else EnigoColor.fgAlpha(dark, 0.1f), RoundedCornerShape(EnigoRadius.control.dp))
            .clickable(onClick = onClick)
            .padding(vertical = 16.dp, horizontal = 18.dp)
    ) {
        Text(
            text,
            color = if (selected) EnigoColor.accent(dark) else EnigoColor.body(dark),
            fontFamily = EnigoFont.frauncesFamily(500),
            fontSize = EnigoFont.answerOptionSize
        )
    }
}

@Composable
fun SelectableChip(text: String, selected: Boolean, onClick: () -> Unit) {
    val dark = isSystemInDarkTheme()
    Box(
        modifier = Modifier
            .clip(CircleShape)
            .background(if (selected) EnigoColor.goldAlpha(dark, 0.12f) else EnigoColor.fgAlpha(dark, 0.05f))
            .border(1.dp, if (selected) EnigoColor.accent(dark).copy(alpha = 0.55f) else EnigoColor.fgAlpha(dark, 0.1f), CircleShape)
            .clickable(onClick = onClick)
            .padding(vertical = 10.dp, horizontal = 14.dp)
    ) {
        Text(
            text,
            color = if (selected) EnigoColor.accent(dark) else EnigoColor.body(dark),
            fontFamily = EnigoFont.frauncesFamily(500),
            fontSize = EnigoFont.chipLabelSize
        )
    }
}

@Composable
fun ProgressDots(count: Int, index: Int) {
    val dark = isSystemInDarkTheme()
    Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
        repeat(count) { i ->
            Box(
                modifier = Modifier
                    .height(6.dp)
                    .width(if (i == index) 22.dp else 6.dp)
                    .clip(CircleShape)
                    .background(if (i == index) EnigoColor.accent(dark) else EnigoColor.fgAlpha(dark, 0.16f))
            )
        }
    }
}

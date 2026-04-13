package com.kelpie.browser.ui

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.kelpie.browser.browser.BrowserTab

enum class ScrollDirection { UP, DOWN }

/** Safari-style bottom bar with tab strip + URL field. Collapses to a pill on scroll. */
@Composable
fun BottomBar(
    tabs: List<BrowserTab>,
    activeTabId: String?,
    currentUrl: String,
    canGoBack: Boolean,
    canGoForward: Boolean,
    isCollapsed: Boolean,
    onNavigate: (String) -> Unit,
    onBack: () -> Unit,
    onForward: () -> Unit,
    onAddTab: () -> Unit,
    onCloseTab: (String) -> Unit,
    onSelectTab: (String) -> Unit,
    onExpand: () -> Unit,
) {
    Surface(tonalElevation = 2.dp) {
        Column(modifier = Modifier.fillMaxWidth()) {
            HorizontalDivider()

            AnimatedVisibility(visible = isCollapsed, enter = fadeIn(), exit = fadeOut()) {
                CollapsedPill(url = currentUrl, onExpand = onExpand)
            }
            AnimatedVisibility(visible = !isCollapsed, enter = fadeIn(), exit = fadeOut()) {
                Column {
                    if (tabs.size > 1) {
                        TabStrip(
                            tabs = tabs,
                            activeTabId = activeTabId,
                            onAddTab = onAddTab,
                            onCloseTab = onCloseTab,
                            onSelectTab = onSelectTab,
                        )
                    }
                    ExpandedBar(
                        currentUrl = currentUrl,
                        canGoBack = canGoBack,
                        canGoForward = canGoForward,
                        onNavigate = onNavigate,
                        onBack = onBack,
                        onForward = onForward,
                        tabCount = tabs.size,
                        onAddTab = onAddTab,
                    )
                }
            }
        }
    }
}

@Composable
private fun ExpandedBar(
    currentUrl: String,
    canGoBack: Boolean,
    canGoForward: Boolean,
    onNavigate: (String) -> Unit,
    onBack: () -> Unit,
    onForward: () -> Unit,
    tabCount: Int,
    onAddTab: () -> Unit,
) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier.fillMaxWidth().padding(horizontal = 8.dp, vertical = 4.dp),
    ) {
        IconButton(onClick = onBack, enabled = canGoBack, modifier = Modifier.size(36.dp)) {
            Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back", modifier = Modifier.size(18.dp))
        }
        IconButton(onClick = onForward, enabled = canGoForward, modifier = Modifier.size(36.dp)) {
            Icon(Icons.AutoMirrored.Filled.ArrowForward, contentDescription = "Forward", modifier = Modifier.size(18.dp))
        }

        HistoryAutocompleteField(
            currentUrl = currentUrl,
            placeholder = "URL",
            onNavigate = onNavigate,
            shape = RoundedCornerShape(50),
            textStyle = MaterialTheme.typography.bodySmall,
            modifier = Modifier.weight(1f).padding(horizontal = 4.dp).height(44.dp),
        )

        TabCountButton(count = tabCount, onClick = onAddTab)
    }
}

@Composable
private fun TabStrip(
    tabs: List<BrowserTab>,
    activeTabId: String?,
    onAddTab: () -> Unit,
    onCloseTab: (String) -> Unit,
    onSelectTab: (String) -> Unit,
) {
    Row(
        modifier =
            Modifier
                .fillMaxWidth()
                .horizontalScroll(rememberScrollState())
                .padding(horizontal = 8.dp, vertical = 4.dp),
        horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        tabs.forEach { tab ->
            TabPill(
                tab = tab,
                isActive = tab.id == activeTabId,
                canClose = tabs.size > 1,
                onSelect = { onSelectTab(tab.id) },
                onClose = { onCloseTab(tab.id) },
            )
        }

        IconButton(onClick = onAddTab, modifier = Modifier.size(28.dp)) {
            Icon(Icons.Filled.Add, contentDescription = "New tab", modifier = Modifier.size(14.dp))
        }
    }
}

@Composable
private fun TabPill(
    tab: BrowserTab,
    isActive: Boolean,
    canClose: Boolean,
    onSelect: () -> Unit,
    onClose: () -> Unit,
) {
    val bg =
        if (isActive) {
            MaterialTheme.colorScheme.surfaceContainerHighest
        } else {
            MaterialTheme.colorScheme.surfaceContainerLow
        }

    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier =
            Modifier
                .clip(RoundedCornerShape(50))
                .background(bg)
                .clickable { onSelect() }
                .padding(horizontal = 10.dp, vertical = 6.dp),
    ) {
        Text(
            text = tabTitle(tab),
            fontSize = 12.sp,
            fontWeight = if (isActive) FontWeight.SemiBold else FontWeight.Normal,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.widthIn(max = 120.dp, min = 0.dp),
        )

        if (canClose) {
            Box(
                contentAlignment = Alignment.Center,
                modifier =
                    Modifier
                        .padding(start = 4.dp)
                        .size(16.dp)
                        .clip(CircleShape)
                        .background(MaterialTheme.colorScheme.surfaceContainerHigh)
                        .clickable { onClose() },
            ) {
                Icon(
                    Icons.Filled.Close,
                    contentDescription = "Close tab",
                    modifier = Modifier.size(8.dp),
                )
            }
        }
    }
}

@Composable
private fun CollapsedPill(
    url: String,
    onExpand: () -> Unit,
) {
    Box(
        contentAlignment = Alignment.Center,
        modifier =
            Modifier
                .fillMaxWidth()
                .padding(horizontal = 40.dp, vertical = 6.dp)
                .clip(RoundedCornerShape(50))
                .background(MaterialTheme.colorScheme.surfaceContainerHigh)
                .clickable { onExpand() }
                .padding(horizontal = 16.dp, vertical = 10.dp),
    ) {
        Text(
            text = domainFromUrl(url),
            fontSize = 13.sp,
            fontWeight = FontWeight.Medium,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
    }
}

@Composable
private fun TabCountButton(
    count: Int,
    onClick: () -> Unit,
) {
    IconButton(onClick = onClick, modifier = Modifier.size(36.dp)) {
        Box(contentAlignment = Alignment.Center) {
            Box(
                modifier =
                    Modifier
                        .size(24.dp)
                        .clip(RoundedCornerShape(6.dp))
                        .background(MaterialTheme.colorScheme.surfaceContainerHighest),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = "$count",
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Bold,
                )
            }
        }
    }
}

private fun tabTitle(tab: BrowserTab): String {
    if (tab.isStartPage) return "Start Page"
    if (tab.pageTitle.isNotEmpty()) return tab.pageTitle
    return domainFromUrl(tab.currentUrl)
}

private fun domainFromUrl(url: String): String {
    if (url.isEmpty()) return "New Tab"
    return try {
        val host = java.net.URI(url).host ?: return url
        if (host.startsWith("www.")) host.substring(4) else host
    } catch (_: Exception) {
        url
    }
}

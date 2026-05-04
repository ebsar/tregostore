package store.trego.mobile.ui.components

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import store.trego.mobile.ui.theme.TregoColors

@Composable
fun TregoButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    isLoading: Boolean = false,
    isDestructive: Boolean = false,
    isSecondary: Boolean = false,
    icon: ImageVector? = null
) {
    val containerColor = when {
        isDestructive -> TregoColors.error
        isSecondary -> TregoColors.softAccentLight
        else -> TregoColors.accent
    }
    
    val contentColor = when {
        isDestructive -> Color.White
        isSecondary -> TregoColors.accent
        else -> Color.White
    }

    Button(
        onClick = onClick,
        modifier = modifier
            .fillMaxWidth()
            .height(54.dp),
        enabled = enabled && !isLoading,
        shape = RoundedCornerShape(16.dp),
        colors = ButtonDefaults.buttonColors(
            containerColor = containerColor,
            contentColor = contentColor,
            disabledContainerColor = containerColor.copy(alpha = 0.5f),
            disabledContentColor = contentColor.copy(alpha = 0.5f)
        ),
        elevation = null,
        contentPadding = PaddingValues(horizontal = 16.dp)
    ) {
        if (isLoading) {
            CircularProgressIndicator(
                modifier = Modifier.size(20.dp),
                color = contentColor,
                strokeWidth = 2.dp
            )
        } else {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.Center
            ) {
                if (icon != null) {
                    Icon(icon, contentDescription = null, modifier = Modifier.size(18.dp))
                    Spacer(Modifier.width(8.dp))
                }
                Text(
                    text = text,
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.Black,
                    letterSpacing = 0.sp
                )
            }
        }
    }
}

@Composable
fun TregoTextField(
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String,
    modifier: Modifier = Modifier,
    label: String? = null,
    isError: Boolean = false,
    errorMessage: String? = null,
    keyboardOptions: KeyboardOptions = KeyboardOptions.Default,
    visualTransformation: VisualTransformation = VisualTransformation.None,
    trailingIcon: @Composable (() -> Unit)? = null
) {
    Column(modifier = modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(6.dp)) {
        if (label != null) {
            Text(
                text = label.uppercase(),
                style = MaterialTheme.typography.labelLarge,
                color = TregoColors.secondaryTextLight,
                fontWeight = FontWeight.Black,
                fontSize = 11.sp
            )
        }
        
        OutlinedTextField(
            value = value,
            onValueChange = onValueChange,
            modifier = Modifier.fillMaxWidth(),
            placeholder = { 
                Text(
                    placeholder, 
                    style = MaterialTheme.typography.bodyLarge,
                    color = TregoColors.secondaryTextLight.copy(alpha = 0.6f)
                ) 
            },
            shape = RoundedCornerShape(14.dp),
            colors = OutlinedTextFieldDefaults.colors(
                focusedContainerColor = TregoColors.mutedSurfaceLight,
                unfocusedContainerColor = TregoColors.mutedSurfaceLight,
                focusedBorderColor = TregoColors.accent,
                unfocusedBorderColor = TregoColors.borderLight,
                errorBorderColor = TregoColors.error,
                focusedTextColor = TregoColors.primaryTextLight,
                unfocusedTextColor = TregoColors.primaryTextLight
            ),
            isError = isError,
            keyboardOptions = keyboardOptions,
            visualTransformation = visualTransformation,
            trailingIcon = trailingIcon,
            singleLine = true,
            textStyle = MaterialTheme.typography.bodyLarge.copy(fontWeight = FontWeight.Bold)
        )
        
        if (isError && errorMessage != null) {
            Text(
                text = errorMessage,
                style = MaterialTheme.typography.labelSmall,
                color = TregoColors.error,
                modifier = Modifier.padding(start = 4.dp)
            )
        }
    }
}

@Composable
fun TregoCard(
    modifier: Modifier = Modifier,
    onClick: (() -> Unit)? = null,
    backgroundColor: Color = Color.White,
    content: @Composable ColumnScope.() -> Unit
) {
    Surface(
        modifier = modifier.fillMaxWidth(),
        shape = RoundedCornerShape(22.dp),
        color = backgroundColor,
        border = BorderStroke(1.dp, TregoColors.borderLight.copy(alpha = 0.5f)),
        tonalElevation = 1.dp,
        onClick = onClick ?: {},
        enabled = onClick != null
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            content()
        }
    }
}

@Composable
fun TregoHeader(
    title: String,
    subtitle: String? = null,
    onBack: (() -> Unit)? = null,
    action: @Composable (RowScope.() -> Unit)? = null
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            if (onBack != null) {
                IconButton(
                    onClick = onBack,
                    modifier = Modifier
                        .size(40.dp)
                        .tregoGlassCircleBackground()
                ) {
                    Icon(
                        Icons.AutoMirrored.Filled.ArrowBack, 
                        contentDescription = "Back",
                        modifier = Modifier.size(20.dp)
                    )
                }
            } else {
                Spacer(Modifier.size(40.dp))
            }
            
            if (action != null) {
                Row { action() }
            } else {
                Spacer(Modifier.size(40.dp))
            }
        }
        
        Spacer(Modifier.height(8.dp))
        
        Text(
            text = title,
            style = MaterialTheme.typography.headlineLarge,
            fontWeight = FontWeight.Black,
            color = TregoColors.primaryTextLight
        )
        
        if (subtitle != null) {
            Text(
                text = subtitle,
                style = MaterialTheme.typography.bodyLarge,
                color = TregoColors.secondaryTextLight
            )
        }
    }
}

@Composable
fun Modifier.tregoGlassCircleBackground(): Modifier = this
    .clip(CircleShape)
    .background(TregoColors.mutedSurfaceLight.copy(alpha = 0.8f))

@Composable
fun TregoStatusPill(status: String) {
    val normalized = status.lowercase()
    val (label, color) = when (normalized) {
        "delivered", "completed", "approved", "refunded" -> "Dërguar" to TregoColors.success
        "cancelled", "rejected", "failed" -> "Anuluar" to TregoColors.error
        "pending", "requested" -> "Në pritje" to TregoColors.accent
        "shipped" -> "Në rrugë" to TregoColors.accent
        else -> status.uppercase() to TregoColors.secondaryTextLight
    }
    
    Surface(
        shape = CircleShape,
        color = color.copy(alpha = 0.12f),
        modifier = Modifier.wrapContentSize()
    ) {
        Text(
            text = label,
            modifier = Modifier.padding(horizontal = 10.dp, vertical = 4.dp),
            style = MaterialTheme.typography.labelSmall,
            color = color,
            fontWeight = FontWeight.Black,
            fontSize = 10.sp
        )
    }
}

@Composable
fun TregoEmptyState(
    title: String,
    subtitle: String,
    icon: ImageVector? = null
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        if (icon != null) {
            Icon(
                icon, 
                contentDescription = null, 
                modifier = Modifier.size(48.dp),
                tint = TregoColors.accent.copy(alpha = 0.2f)
            )
        }
        Text(
            text = title,
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.Black,
            textAlign = TextAlign.Center
        )
        Text(
            text = subtitle,
            style = MaterialTheme.typography.bodyMedium,
            color = TregoColors.secondaryTextLight,
            textAlign = TextAlign.Center
        )
    }
}

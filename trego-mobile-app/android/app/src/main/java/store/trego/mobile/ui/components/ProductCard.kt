package store.trego.mobile.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import store.trego.mobile.data.model.Product
import store.trego.mobile.ui.theme.TregoColors

@Composable
fun ProductCard(
    product: Product,
    modifier: Modifier = Modifier,
    onClick: () -> Unit
) {
    Surface(
        modifier = modifier
            .fillMaxWidth()
            .clickable(onClick = onClick),
        shape = RoundedCornerShape(22.dp),
        color = TregoColors.cardSurfaceLight,
        tonalElevation = 1.dp
    ) {
        Column {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .aspectRatio(1.1f)
                    .clip(RoundedCornerShape(22.dp))
                    .background(TregoColors.mutedSurfaceLight)
            ) {
                AsyncImage(
                    model = product.imagePath,
                    contentDescription = product.title,
                    modifier = Modifier.fillMaxSize(),
                    contentScale = ContentScale.Crop
                )
                
                if (product.compareAtPrice != null && product.price != null) {
                    val discount = ((1 - (product.price / product.compareAtPrice)) * 100).toInt()
                    if (discount > 0) {
                        Surface(
                            modifier = Modifier
                                .padding(12.dp)
                                .align(Alignment.TopEnd),
                            shape = RoundedCornerShape(10.dp),
                            color = TregoColors.accent,
                            contentColor = Color.White
                        ) {
                            Text(
                                text = "-$discount%",
                                modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
                                style = MaterialTheme.typography.labelSmall,
                                fontWeight = FontWeight.Black,
                                fontSize = 10.sp
                            )
                        }
                    }
                }
            }
            
            Column(modifier = Modifier.padding(14.dp)) {
                Text(
                    text = (product.businessName ?: "TREGO").uppercase(),
                    style = MaterialTheme.typography.labelSmall,
                    color = TregoColors.accent,
                    fontWeight = FontWeight.Black,
                    maxLines = 1,
                    letterSpacing = 0.5.sp
                )
                Text(
                    text = product.title,
                    style = MaterialTheme.typography.bodyMedium.copy(
                        fontWeight = FontWeight.Bold,
                        fontSize = 14.sp
                    ),
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                    color = TregoColors.primaryTextLight,
                    modifier = Modifier.padding(top = 2.dp, bottom = 6.dp)
                )
                
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        text = product.price?.let { "€$it" } ?: "-",
                        style = MaterialTheme.typography.titleMedium.copy(
                            fontWeight = FontWeight.Black
                        ),
                        color = TregoColors.primaryTextLight
                    )
                    if (product.compareAtPrice != null) {
                        Text(
                            text = "€${product.compareAtPrice}",
                            style = MaterialTheme.typography.labelSmall.copy(
                                textDecoration = androidx.compose.ui.text.style.TextDecoration.LineThrough
                            ),
                            color = TregoColors.secondaryTextLight,
                            modifier = Modifier.padding(start = 6.dp)
                        )
                    }
                }
            }
        }
    }
}

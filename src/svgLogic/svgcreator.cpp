#include "svgcreator.h"

#include <QObject>
#include <QSvgRenderer>
#include <QPainter>
#include <QApplication>
#include <QFile>

QImage SvgCreator::makeImage(const QString& path, const QColor& color, const QSize& size, const qreal dpr)
{
    QImage image(size.width() * dpr, size.height() * dpr, QImage::Format_ARGB32_Premultiplied);
    image.setDevicePixelRatio(dpr);
    image.fill(Qt::transparent);

    QPainter painter(&image);

    QSvgRenderer renderer(path);
    renderer.render(&painter, QRectF(0, 0, size.width(), size.height()));
    painter.setCompositionMode(QPainter::CompositionMode_SourceIn);
    painter.fillRect(image.rect(), color);
    painter.end();

    return image;
}

QImage SvgCreator::colorizeSvgDual(
    const QString& path,
    const QColor& backgroundColor,
    const QColor& foregroundColor,
    const QSize& size,
    const qreal dpr
)
{
    QFile file(path);

    if (!file.open(QIODevice::ReadOnly))
        return {};

    QString svg = QString::fromUtf8(file.readAll());
    file.close();

    svg.replace(
        "{background}",
        backgroundColor.name(),
        Qt::CaseInsensitive
    );

    svg.replace(
        "{foreground}",
        foregroundColor.name(),
        Qt::CaseInsensitive
    );

    QImage image(
        size.width() * dpr,
        size.height() * dpr,
        QImage::Format_ARGB32_Premultiplied
    );
    image.setDevicePixelRatio(dpr);
    image.fill(Qt::transparent);

    QSvgRenderer renderer(svg.toUtf8());

    QPainter painter(&image);

    renderer.render(
        &painter,
        QRectF(0, 0, size.width(), size.height())
    );

    painter.end();

    return image;
}

static QColor interpolateHsv(
    const QColor& a,
    const QColor& b,
    float t)
{
    float h1, s1, v1, a1;
    float h2, s2, v2, a2;

    a.getHsvF(&h1, &s1, &v1, &a1);
    b.getHsvF(&h2, &s2, &v2, &a2);

    // Shortest hue path
    if (std::abs(h2 - h1) > 0.5){
        if (h1 > h2)
            h2 += 1.0;
        else
            h1 += 1.0;
    }

    float h = std::fmod(h1 + (h2 - h1) * t, 1.0);
    float s = s1 + (s2 - s1) * t;
    float v = v1 + (v2 - v1) * t;
    float alpha = a1 + (a2 - a1) * t;

    return QColor::fromHsvF(h, s, v, alpha);
}

QIcon SvgCreator::colorizeGradientSvg(
    const QString& path,
    const QColor& startColor,
    const QColor& endColor,
    const QSize& size,
    qreal dpr)
{
    QFile file(path);

    if (!file.open(QIODevice::ReadOnly))
        return {};

    QString svg = QString::fromUtf8(file.readAll());

    const QColor stop1 = interpolateHsv(startColor, endColor, 0.22f);
    const QColor stop2 = interpolateHsv(startColor, endColor, 0.52f);
    const QColor stop3 = interpolateHsv(startColor, endColor, 0.78f);

    svg.replace("{START_COLOR}", startColor.name(QColor::HexRgb));
    svg.replace("{STOP1}", stop1.name(QColor::HexRgb));
    svg.replace("{STOP2}", stop2.name(QColor::HexRgb));
    svg.replace("{STOP3}", stop3.name(QColor::HexRgb));
    svg.replace("{END_COLOR}", endColor.name(QColor::HexRgb));

    QPixmap pixmap(size * dpr);
    pixmap.setDevicePixelRatio(dpr);
    pixmap.fill(Qt::transparent);

    QSvgRenderer renderer(svg.toUtf8());

    QPainter painter(&pixmap);
    painter.setRenderHint(QPainter::Antialiasing);
    painter.setRenderHint(QPainter::SmoothPixmapTransform);

    renderer.render(
        &painter,
        QRectF(0, 0, size.width(), size.height()));

    return QIcon(pixmap);
}

QIcon SvgCreator::colorizeAlbumSvg(
    const QString& path,
    const QColor& outerColor,
    const QColor& ringColor,
    const QColor& centerColor,
    const QColor& dotColor,
    const QSize& size,
    const qreal dpr
)
{
    QFile file(path);

    if (!file.open(QIODevice::ReadOnly))
        return {};

    QString svg = QString::fromUtf8(file.readAll());
    file.close();

    svg.replace("{outer}", outerColor.name(), Qt::CaseInsensitive);
    svg.replace("{rings}", ringColor.name(), Qt::CaseInsensitive);
    svg.replace("{center}", centerColor.name(), Qt::CaseInsensitive);
    svg.replace("{dot}", dotColor.name(), Qt::CaseInsensitive);

    QPixmap pixmap(size.width() * dpr,
                   size.height() * dpr);

    pixmap.setDevicePixelRatio(dpr);
    pixmap.fill(Qt::transparent);

    QSvgRenderer renderer(svg.toUtf8());

    QPainter painter(&pixmap);
    painter.setRenderHint(QPainter::Antialiasing);
    painter.setRenderHint(QPainter::SmoothPixmapTransform);

    renderer.render(&painter,
                    QRectF(0, 0, size.width(), size.height()));

    painter.end();

    return QIcon(pixmap);
}
#pragma once

#include <QSvgRenderer>
#include <QIcon>
#include <QPainter>

class SvgCreator
{

public:
    static QImage makeImage(const QString& path, const QColor& color, const QSize& size, const qreal dpr);
    

    static QImage colorizeSvgDual(
        const QString& path,
        const QColor& backgroundColor,
        const QColor& foregroundColor,
        const QSize& size,
        const qreal dpr
    );

    static QIcon colorizeGradientSvg(
        const QString& path,
        const QColor& startColor,
        const QColor& endColor,
        const QSize& size,
        qreal dpr
    );

    static QIcon colorizeAlbumSvg(
        const QString& path,
        const QColor& outerColor,
        const QColor& ringColor,
        const QColor& centerColor,
        const QColor& dotColor,
        const QSize& size,
        const qreal dpr
    );
};
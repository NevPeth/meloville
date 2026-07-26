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

    static QImage colorizeGradientSvg(
        const QString& path,
        const QColor& startColor,
        const QColor& endColor,
        const QSize& size,
        qreal dpr
    );
};
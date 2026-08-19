#pragma once
#include <QQuickImageProvider>
#include <QMap>
#include "svgcreator.h"

class SvgImageProvider : public QQuickImageProvider
{
public:
    struct IconConfig
    {
        enum class RenderType {
            SingleColor,
            DualColor,
            GradientColor
        };

        QString path;
        RenderType renderType = RenderType::SingleColor;

        // Single‑color
        QColor color;

        // Dual‑color
        QColor backgroundColor;
        QColor foregroundColor;

        // Gradient
        QColor startColor;
        QColor endColor;

        QSize size;
    };

    SvgImageProvider()
        : QQuickImageProvider(QQuickImageProvider::Image) {}

    void registerIcon(const QString& id,
                  const QString& path,
                  const QColor& color,
                  const QSize& size)
    {
        IconConfig cfg;
        cfg.path = path;
        cfg.renderType = IconConfig::RenderType::SingleColor;
        cfg.color = color;
        cfg.size = size;

        configs[id] = cfg;
    }

    void registerDualIcon(
        const QString& id,
        const QString& path,
        const QColor& backgroundColor,
        const QColor& foregroundColor,
        const QSize& size
    ){
        IconConfig cfg;
        cfg.path = path;
        cfg.renderType = IconConfig::RenderType::DualColor;
        cfg.backgroundColor = backgroundColor;
        cfg.foregroundColor = foregroundColor;
        cfg.size = size;

        configs[id] = cfg;
    }

    void registerGradientIcon(
        const QString& id,
        const QString& path,
        const QColor& startColor,
        const QColor& endColor,
        const QSize& size)
    {
        IconConfig cfg;
        cfg.path = path;
        cfg.renderType = IconConfig::RenderType::GradientColor;
        cfg.startColor = startColor;
        cfg.endColor = endColor;
        cfg.size = size;
        configs[id] = cfg;
    }

    QImage requestImage(const QString& id, QSize* size, const QSize& requestedSize) override
    {
        const auto &cfg = configs[id];
        qreal dpr = qApp->primaryScreen()->devicePixelRatio();
        QSize logicalSize = requestedSize.isValid() ? requestedSize : cfg.size;
        if (size) *size = logicalSize;

        switch (cfg.renderType)
        {
        case IconConfig::RenderType::SingleColor:
            return SvgCreator::makeImage(cfg.path, cfg.color, logicalSize, dpr);
        case IconConfig::RenderType::DualColor:
            return SvgCreator::colorizeSvgDual(cfg.path, cfg.backgroundColor, cfg.foregroundColor, logicalSize, dpr);
        case IconConfig::RenderType::GradientColor:   // <-- new
            return SvgCreator::colorizeGradientSvg(cfg.path, cfg.startColor, cfg.endColor, logicalSize, dpr);
        }
        return {};
    }

private:
    QMap<QString, IconConfig> configs;
};
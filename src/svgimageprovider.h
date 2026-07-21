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
            DualColor
        };

        QString path;
        RenderType renderType = RenderType::SingleColor;

        // Single-color
        QColor color;

        // Dual-color
        QColor backgroundColor;
        QColor foregroundColor;

        QSize size;
    };
    // struct IconConfig {
    //     QString path;
    //     QColor color;
    //     QSize  size;
    // };

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

    // // Call this from C++ before QML loads, e.g. in main.cpp
    // void registerIcon(const QString& id, const QString& svgPath,
    //                   const QColor& color, const QSize& size)
    // {
    //     configs[id] = { svgPath, color, size };
    // }

    void registerDualIcon(const QString& id,
                      const QString& path,
                      const QColor& backgroundColor,
                      const QColor& foregroundColor,
                      const QSize& size)
    {
        IconConfig cfg;
        cfg.path = path;
        cfg.renderType = IconConfig::RenderType::DualColor;
        cfg.backgroundColor = backgroundColor;
        cfg.foregroundColor = foregroundColor;
        cfg.size = size;

        configs[id] = cfg;
    }

    QImage requestImage(const QString& id,
                                      QSize* size,
                                      const QSize& requestedSize)
    {
        const auto &cfg = configs[id];

        qreal dpr = qApp->primaryScreen()->devicePixelRatio();
        QSize logicalSize = requestedSize.isValid()
                                ? requestedSize
                                : cfg.size;

        if (size)
            *size = logicalSize;

        switch (cfg.renderType)
        {
        case IconConfig::RenderType::SingleColor:
            return SvgCreator::makeImage(
                cfg.path,
                cfg.color,
                logicalSize,
                dpr);

        case IconConfig::RenderType::DualColor:
            return SvgCreator::colorizeSvgDual(
                cfg.path,
                cfg.backgroundColor,
                cfg.foregroundColor,
                logicalSize,
                dpr);
        }

        return {};
    }

    // QImage requestImage(const QString& id, QSize* size,
    //                 const QSize& requestedSize) override
    // {
    //     const IconConfig& cfg = configs[id];
    //     qreal dpr = qApp->primaryScreen()->devicePixelRatio();
    //     QSize logicalSize = requestedSize.isValid() ? requestedSize : cfg.size;

    //     // Report LOGICAL size so QML lays it out at the right dimensions
    //     if (size) *size = logicalSize;

    //     return SvgCreator::makeImage(cfg.path, cfg.color, logicalSize, dpr);
    // }

private:
    QMap<QString, IconConfig> configs;
};
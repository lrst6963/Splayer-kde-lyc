#include "SPlayerClient.h"
#include <QApplication>
#include <QIcon>
#include <QLocalServer>
#include <QLocalSocket>

#include <QQmlApplicationEngine>
#include <QQmlContext>

int main(int argc, char *argv[]) {
#ifdef Q_OS_LINUX
  // 强制使用 XWayland
  qputenv("QT_QPA_PLATFORM", "xcb");
#endif

#if QT_VERSION < QT_VERSION_CHECK(6, 0, 0)
  QCoreApplication::setAttribute(Qt::AA_EnableHighDpiScaling);
#endif

  QApplication app(argc, argv);
  app.setOrganizationName("SPlayer");
  app.setOrganizationDomain("splayer.org");
  app.setApplicationName("SPlayer Desktop Lyric");

  // 单实例检测
  const QString serverName = "splayer-kde-lyric-instance";
  {
      QLocalSocket socket;
      socket.connectToServer(serverName);
      if (socket.waitForConnected(500)) {
          // 已有实例在运行，通知它激活窗口
          // qDebug() << "Another instance is running, activating it...";
          socket.write("activate");
          socket.waitForBytesWritten(1000);
          socket.disconnectFromServer();
          return 0; // 退出当前实例
      }
  }

  SPlayerClient client;
  
  // 启动单实例服务器
  QLocalServer singleInstanceServer;
  QObject::connect(&singleInstanceServer, &QLocalServer::newConnection, [&singleInstanceServer, &client](){
      QLocalSocket* socket = singleInstanceServer.nextPendingConnection();
      if (socket) {
          socket->waitForReadyRead(500);
          // 只要有连接请求，就激活窗口
          client.activateWindow();
          socket->deleteLater();
      }
  });
  
  // 清理可能残留的 socket 文件 (Unix)
  QLocalServer::removeServer(serverName);
  if (!singleInstanceServer.listen(serverName)) {
      qWarning() << "Failed to start single instance server:" << singleInstanceServer.errorString();
  }

  client.connectToServer();

  QQmlApplicationEngine engine;
  engine.rootContext()->setContextProperty("splayer", &client);

  const QUrl url(QStringLiteral("qrc:/qml/main.qml"));
  QObject::connect(
      &engine, &QQmlApplicationEngine::objectCreated, &app,
      [url](QObject *obj, const QUrl &objUrl) {
        if (!obj && url == objUrl)
          QCoreApplication::exit(-1);
      },
      Qt::QueuedConnection);
  engine.load(url);

  return app.exec();
}

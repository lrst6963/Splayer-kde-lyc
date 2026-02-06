#ifndef SPLAYERCLIENT_H
#define SPLAYERCLIENT_H

#include <QDebug>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QObject>
#include <QTimer>
#include <QWebSocket>
#include <QSystemTrayIcon>
#include <QMenu>
#include <QAction>

class SPlayerClient : public QObject {
  Q_OBJECT
  Q_PROPERTY(QString currentSong READ currentSong NOTIFY songChanged)
  Q_PROPERTY(QString currentArtist READ currentArtist NOTIFY songChanged)
  Q_PROPERTY(QString currentLyric READ currentLyric NOTIFY lyricChanged)
  Q_PROPERTY(
      QVariantMap currentLyricLine READ currentLyricLine NOTIFY lyricChanged)
  Q_PROPERTY(int currentLineIndex READ currentLineIndex NOTIFY lyricChanged)
  Q_PROPERTY(QVariantMap lyricLineEven READ lyricLineEven NOTIFY lyricChanged)
  Q_PROPERTY(QVariantMap lyricLineOdd READ lyricLineOdd NOTIFY lyricChanged)
  Q_PROPERTY(QVariantList lyrics READ lyrics NOTIFY lyricChanged)
  Q_PROPERTY(bool hasTranslation READ hasTranslation NOTIFY lyricChanged)
  Q_PROPERTY(bool isPlaying READ isPlaying NOTIFY playStateChanged)

  // QML 简单字符串替换属性
  Q_PROPERTY(double duration READ duration NOTIFY progressChanged)
  Q_PROPERTY(double currentTime READ currentTime NOTIFY progressChanged)

  // 托盘属性
  Q_PROPERTY(bool trayShowLyrics READ trayShowLyrics WRITE setTrayShowLyrics NOTIFY trayShowLyricsChanged)
  Q_PROPERTY(bool trayLocked READ trayLocked WRITE setTrayLocked NOTIFY trayLockedChanged)

public:
  explicit SPlayerClient(QObject *parent = nullptr);
  ~SPlayerClient();

  QString currentSong() const { return m_currentSong; }
  QString currentArtist() const { return m_currentArtist; }
  QString currentLyric() const { return m_currentLyric; }
  QVariantMap currentLyricLine() const;
  int currentLineIndex() const { return m_currentLineIndex; }
  QVariantMap lyricLineEven() const;
  QVariantMap lyricLineOdd() const;
  QVariantList lyrics() const { return m_lyricsList; }
  bool hasTranslation() const { return m_hasTranslation; }
  bool isPlaying() const { return m_isPlaying; }
  double duration() const { return m_duration; }
  double currentTime() const { return m_currentTime; }

  bool trayShowLyrics() const { return m_trayShowLyrics; }
  void setTrayShowLyrics(bool show);

  bool trayLocked() const { return m_trayLocked; }
  void setTrayLocked(bool locked);

  Q_INVOKABLE void connectToServer();
  Q_INVOKABLE void sendControl(const QString &command);
  Q_INVOKABLE void setupTrayIcon();
  Q_INVOKABLE void activateWindow();

signals:
  void songChanged();
  void lyricChanged();
  void playStateChanged();
  void progressChanged();
  void connectionStatusChanged(bool connected);

  // 托盘信号
  void trayShowLyricsChanged();
  void trayLockedChanged();
  void requestShowControlPanel();
  void requestQuit();
  void requestActivate();

private slots:
  void onConnected();
  void onDisconnected();
  void onTextMessageReceived(QString message);
  void onError(QAbstractSocket::SocketError error);
  void onTrayActivated(QSystemTrayIcon::ActivationReason reason);

private:
  void processMessage(const QJsonObject &root);
  void handleSongChange(const QJsonObject &data);
  void handleStatusChange(const QJsonObject &data);
  void handleProgressChange(const QJsonObject &data);
  void handleLyricChange(const QJsonObject &data);
  void handleWelcome(const QJsonObject &data);

  void updateCurrentLyricLine();
  void updateTrayMenu();
  void resetState();

  QWebSocket m_webSocket;
  QString m_url;
  QTimer m_reconnectTimer;
  QTimer m_interpolationTimer; // 60fps 定时器用于平滑更新

  QString m_currentSong;
  QString m_currentArtist;
  QString m_currentLyric; // 简化：目前仅保留当前行
  int m_currentLineIndex = -1;
  bool m_isPlaying;
  double m_duration;
  double m_currentTime;

  // 用于时间插值
  double m_baseTime;      // 上次 WebSocket 更新的基础时间（秒）
  qint64 m_baseTimestamp; // 接收到 m_baseTime 的时间戳（毫秒）
  bool m_hasTranslation = false;
  qint64 m_lastLyricUpdateTimestamp = 0;

  // 托盘成员
  QSystemTrayIcon *m_trayIcon = nullptr;
  QMenu *m_trayMenu = nullptr;
  QAction *m_showLyricsAction = nullptr;
  QAction *m_lockAction = nullptr;
  bool m_trayShowLyrics = true;
  bool m_trayLocked = false;

  struct WordInfo {
    double startTime; // 秒
    double endTime;   // 秒
    QString word;
  };

  struct LyricLine {
    double time;             // 秒（行开始时间）
    QString text;            // 完整行文本
    QString translatedLyric; // 翻译文本
    QVector<WordInfo> words; // 卡拉OK逐字时间
  };
  QVector<LyricLine> m_lyrics;
  QVariantList m_lyricsList;
};

#endif // SPLAYERCLIENT_H

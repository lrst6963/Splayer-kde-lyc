#include "SPlayerClient.h"
#include <QDateTime>
#include <QDebug>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QApplication>
#include <QStyle>

SPlayerClient::SPlayerClient(QObject *parent)
    : QObject(parent), m_url("ws://localhost:25885"), m_isPlaying(false),
      m_duration(0), m_currentTime(0), m_baseTime(0), m_baseTimestamp(0) {
  connect(&m_webSocket, &QWebSocket::connected, this,
          &SPlayerClient::onConnected);
  connect(&m_webSocket, &QWebSocket::disconnected, this,
          &SPlayerClient::onDisconnected);
  connect(&m_webSocket, &QWebSocket::textMessageReceived, this,
          &SPlayerClient::onTextMessageReceived);
  connect(
      &m_webSocket,
      QOverload<QAbstractSocket::SocketError>::of(&QWebSocket::errorOccurred),
      this, &SPlayerClient::onError);

  m_reconnectTimer.setInterval(3000); // 每 3 秒重试一次
  connect(&m_reconnectTimer, &QTimer::timeout, this,
          &SPlayerClient::connectToServer);

  m_interpolationTimer.setInterval(16);
  connect(&m_interpolationTimer, &QTimer::timeout, this, [this]() {
    if (m_isPlaying && m_baseTimestamp > 0) {
      qint64 now = QDateTime::currentMSecsSinceEpoch();
      double elapsed = (now - m_baseTimestamp) / 1000.0;
      double nextTime = m_baseTime + elapsed;
      if (nextTime < m_currentTime) {
        nextTime = m_currentTime;
      }
      if (!qFuzzyCompare(nextTime, m_currentTime)) {
        m_currentTime = nextTime;
        emit progressChanged();
        updateCurrentLyricLine();
      }
    }
  });
  m_interpolationTimer.start();
}

SPlayerClient::~SPlayerClient() {
  m_webSocket.close();
  if (m_trayIcon) {
    delete m_trayIcon;
  }
  if (m_trayMenu) {
    delete m_trayMenu;
  }
}

void SPlayerClient::setTrayShowLyrics(bool show) {
  if (m_trayShowLyrics != show) {
    m_trayShowLyrics = show;
    updateTrayMenu();
    emit trayShowLyricsChanged();
  }
}

void SPlayerClient::setTrayLocked(bool locked) {
  if (m_trayLocked != locked) {
    m_trayLocked = locked;
    updateTrayMenu();
    emit trayLockedChanged();
  }
}

void SPlayerClient::setupTrayIcon() {
  if (m_trayIcon) return;

  m_trayIcon = new QSystemTrayIcon(this);
  
  // 尝试从主题加载图标（Linux），否则回退到标准样式
  QIcon icon = QIcon::fromTheme("applications-multimedia");
  if (icon.isNull()) {
      // 如果主题图标缺失，则为 Windows/其他平台回退
      // 由于尚未捆绑图标文件，我们使用标准样式图标
      icon = QApplication::style()->standardIcon(QStyle::SP_MediaPlay);
  }
  m_trayIcon->setIcon(icon);
  
  m_trayIcon->setToolTip("SPlayer Lyric");

  m_trayMenu = new QMenu();

  m_showLyricsAction = new QAction("显示歌词", m_trayMenu);
  connect(m_showLyricsAction, &QAction::triggered, this, [this]() {
      setTrayShowLyrics(!m_trayShowLyrics);
  });
  m_trayMenu->addAction(m_showLyricsAction);

  m_lockAction = new QAction("锁定(鼠标穿透)", m_trayMenu);
  connect(m_lockAction, &QAction::triggered, this, [this]() {
      setTrayLocked(!m_trayLocked);
  });
  m_trayMenu->addAction(m_lockAction);

  m_trayMenu->addSeparator();

  QAction *controlPanelAction = new QAction("控制面板", m_trayMenu);
  connect(controlPanelAction, &QAction::triggered, this, &SPlayerClient::requestShowControlPanel);
  m_trayMenu->addAction(controlPanelAction);

  QAction *quitAction = new QAction("退出", m_trayMenu);
  connect(quitAction, &QAction::triggered, this, &SPlayerClient::requestQuit);
  m_trayMenu->addAction(quitAction);

  m_trayIcon->setContextMenu(m_trayMenu);
  m_trayIcon->show();
  
  updateTrayMenu();
}

void SPlayerClient::updateTrayMenu() {
    if (!m_showLyricsAction || !m_lockAction) return;
    
    m_showLyricsAction->setText(m_trayShowLyrics ? "隐藏歌词" : "显示歌词");
    m_lockAction->setText(m_trayLocked ? "解锁" : "锁定(鼠标穿透)");
}

void SPlayerClient::onTrayActivated(QSystemTrayIcon::ActivationReason reason) {
    // 由默认上下文菜单机制处理
}

QVariantMap SPlayerClient::currentLyricLine() const {
  QVariantMap result;

  if (m_lyrics.isEmpty()) {
    return result;
  }

  // 查找当前歌词行索引
  int index = -1;
  for (int i = 0; i < m_lyrics.size(); ++i) {
    if (m_lyrics[i].time <= m_currentTime) {
      index = i;
    } else {
      break;
    }
  }

  if (index < 0 || index >= m_lyrics.size()) {
    return result;
  }

  result["index"] = index;
  const LyricLine &line = m_lyrics[index];
  result["time"] = line.time;

  result["text"] = line.text;
  result["translatedLyric"] = line.translatedLyric;

  // 将单词数组转换为 QVariantList
  QVariantList wordsList;
  for (const auto &word : line.words) {
    QVariantMap wordMap;
    wordMap["startTime"] = word.startTime;
    wordMap["endTime"] = word.endTime;
    wordMap["word"] = word.word;
    wordsList.append(wordMap);
  }
  result["words"] = wordsList;

  return result;
}

QVariantMap SPlayerClient::lyricLineEven() const {
  QVariantMap result;
  if (m_lyrics.isEmpty())
    return result;

  int idx = -1;
  if (m_currentLineIndex < 0) {
    idx = 0;
  } else {
    idx = (m_currentLineIndex % 2 == 0) ? m_currentLineIndex : m_currentLineIndex + 1;
  }

  if (idx >= 0 && idx < m_lyrics.size()) {
    const LyricLine &line = m_lyrics[idx];
    result["time"] = line.time;
    result["text"] = line.text;
    result["translatedLyric"] = line.translatedLyric;
    result["index"] = idx;
    QVariantList wordsList;
    for (const auto &word : line.words) {
      QVariantMap wordMap;
      wordMap["startTime"] = word.startTime;
      wordMap["endTime"] = word.endTime;
      wordMap["word"] = word.word;
      wordsList.append(wordMap);
    }
    result["words"] = wordsList;
  }
  return result;
}

QVariantMap SPlayerClient::lyricLineOdd() const {
  QVariantMap result;
  if (m_lyrics.isEmpty())
    return result;

  int idx = -1;
  if (m_currentLineIndex < 0) {
    idx = 1;
  } else {
    idx = (m_currentLineIndex % 2 != 0) ? m_currentLineIndex : m_currentLineIndex + 1;
  }

  if (idx >= 0 && idx < m_lyrics.size()) {
    const LyricLine &line = m_lyrics[idx];
    result["time"] = line.time;
    result["text"] = line.text;
    result["translatedLyric"] = line.translatedLyric;
    result["index"] = idx;
    QVariantList wordsList;
    for (const auto &word : line.words) {
      QVariantMap wordMap;
      wordMap["startTime"] = word.startTime;
      wordMap["endTime"] = word.endTime;
      wordMap["word"] = word.word;
      wordsList.append(wordMap);
    }
    result["words"] = wordsList;
  }
  return result;
}

void SPlayerClient::connectToServer() {
  if (m_webSocket.state() == QAbstractSocket::ConnectedState) {
    return;
  }
  m_webSocket.open(QUrl(m_url));
}

void SPlayerClient::sendControl(const QString &command) {
  QJsonObject root;
  root["type"] = "control";
  QJsonObject data;
  data["command"] = command;
  root["data"] = data;

  QJsonDocument doc(root);
  m_webSocket.sendTextMessage(
      QString::fromUtf8(doc.toJson(QJsonDocument::Compact)));
}

void SPlayerClient::onConnected() {
  qDebug() << "SPlayer Connected!";
  m_reconnectTimer.stop();
  emit connectionStatusChanged(true);

  // 请求初始信息
  QJsonObject root;
  root["type"] = "get-song-info";
  QJsonDocument doc(root);
  m_webSocket.sendTextMessage(
      QString::fromUtf8(doc.toJson(QJsonDocument::Compact)));
}

void SPlayerClient::onDisconnected() {
  qDebug() << "SPlayer Disconnected. Retrying in 3s...";
  resetState();
  emit connectionStatusChanged(false);
  m_reconnectTimer.start();
}

void SPlayerClient::resetState() {
  m_isPlaying = false;
  emit playStateChanged();

  m_lyrics.clear();
  m_lyricsList.clear();
  m_hasTranslation = false;
  m_currentLyric = "";
  m_currentLineIndex = -1;
  emit lyricChanged();

  m_currentSong = "";
  m_currentArtist = "";
  emit songChanged();

  m_currentTime = 0;
  m_duration = 0;
  emit progressChanged();
}

void SPlayerClient::onError(QAbstractSocket::SocketError error) {
  qDebug() << "WebSocket Error:" << error;
  // 如果断开连接，定时器将处理重连
}

void SPlayerClient::onTextMessageReceived(QString message) {
  // qDebug() << "Msg:" << message;
  QJsonDocument doc = QJsonDocument::fromJson(message.toUtf8());
  if (doc.isNull() || !doc.isObject())
    return;

  processMessage(doc.object());
}

void SPlayerClient::processMessage(const QJsonObject &root) {
  QString type = root["type"].toString();
  QJsonObject data = root["data"].toObject();

  if (type == "welcome") {
    handleWelcome(data);
  } else if (type == "song-change" || type == "song-info") {
    handleSongChange(data);
  } else if (type == "status-change") {
    handleStatusChange(data);
  } else if (type == "progress-change") {
    handleProgressChange(data);
  } else if (type == "lyric-change") {
    handleLyricChange(data);
  }
}

void SPlayerClient::handleWelcome(const QJsonObject &data) {
  Q_UNUSED(data);
  qDebug() << "Server says welcome.";
}

void SPlayerClient::handleSongChange(const QJsonObject &data) {
  //qDebug() << "handleSongChange data:" << data;
  QString newSongName = m_currentSong;

  if (data.contains("name"))
    newSongName = data["name"].toString();
  if (data.contains("playName"))
    newSongName = data["playName"].toString(); // song-info 字段

  bool isSongChanged = (newSongName != m_currentSong);
  m_currentSong = newSongName;
  
  // 如果歌曲切换了，首先重置时间进度
  if (isSongChanged) {
      m_currentTime = 0;
      m_baseTime = 0;
      m_baseTimestamp = 0;
  }

  if (data.contains("artist"))
    m_currentArtist = data["artist"].toString();
  if (data.contains("artistName"))
    m_currentArtist = data["artistName"].toString(); // song-info 字段

  if (data.contains("duration"))
    m_duration = data["duration"].toDouble();

  // 处理 song-info 中的播放状态
  if (data.contains("playStatus")) {
      if (data["playStatus"].isBool()) {
          m_isPlaying = data["playStatus"].toBool();
      } else if (data["playStatus"].isString()) {
          QString status = data["playStatus"].toString();
          m_isPlaying = (status == "true" || status == "playing");
      }
      emit playStateChanged();
  } else if (data.contains("status")) {
      // 如果 playStatus 缺失，回退到 'status' 字段
      if (data["status"].isBool()) {
          m_isPlaying = data["status"].toBool();
      } else if (data["status"].isString()) {
          QString status = data["status"].toString();
          m_isPlaying = (status == "true" || status == "playing");
      }
      emit playStateChanged();
  }
  
  // 处理 song-info 中的当前时间
   if (data.contains("currentTime")) {
       double time = data["currentTime"].toDouble();
       m_currentTime = time / 1000.0;
       m_baseTime = m_currentTime;
       m_baseTimestamp = QDateTime::currentMSecsSinceEpoch();
       emit progressChanged();
   }

  // 如果存在，处理 song-info 中的歌词数据
  if (data.contains("lrcData") || data.contains("yrcData")) {
    handleLyricChange(data);
  } else {
    // 如果没有歌词数据，且最近没有收到歌词，则清除歌词
    // 这处理了 song-change 在 lyric-change 之后不久到达的情况（乱序或拆分消息）
    qint64 now = QDateTime::currentMSecsSinceEpoch();
    
    // 仅当歌曲实际更改且最近（例如 3 秒内）未更新歌词时清除
    if (isSongChanged && (now - m_lastLyricUpdateTimestamp > 3000)) {
         // 仅当上次歌词更新超过 3 秒时清除
         // 这避免了当 lyric-change 在 song-change 之前到达时清除歌词
         m_lyrics.clear();
         m_lyricsList.clear();
         m_hasTranslation = false;
         m_currentLyric = "";
         m_currentLineIndex = -1;
         emit lyricChanged();
     }
  }

  emit songChanged();
}

void SPlayerClient::handleStatusChange(const QJsonObject &data) {
  if (data.contains("status")) {
    if (data["status"].isBool()) {
        m_isPlaying = data["status"].toBool();
    } else if (data["status"].isString()) {
        QString status = data["status"].toString();
        m_isPlaying = (status == "true" || status == "playing");
    }
    emit playStateChanged();
  }
}

void SPlayerClient::handleProgressChange(const QJsonObject &data) {
  if (data.contains("currentTime")) {
    double time = data["currentTime"].toDouble();
    double serverTime = time / 1000.0;
    qint64 now = QDateTime::currentMSecsSinceEpoch();

    if (!m_isPlaying) {
        // 如果未播放，直接更新时间而不使用插值逻辑
        m_currentTime = serverTime;
        m_baseTime = serverTime;
        m_baseTimestamp = now;
    } else {
        double expectedTime = m_currentTime;
        if (m_baseTimestamp > 0) {
            double elapsed = (now - m_baseTimestamp) / 1000.0;
            expectedTime = m_baseTime + elapsed;
        }
        double diff = serverTime - expectedTime;
        if (diff > 0.05 || diff < -1.0) {
            m_baseTime = serverTime;
            m_baseTimestamp = now;
            m_currentTime = serverTime;
        } else if (diff > 0.02) {
            m_baseTime = serverTime;
            m_baseTimestamp = now;
            if (serverTime > m_currentTime) {
                m_currentTime = serverTime;
            }
        }
    }

    emit progressChanged();
    updateCurrentLyricLine();
  }
  if (data.contains("duration")) {
    m_duration = data["duration"].toDouble();
  }
}

void SPlayerClient::handleLyricChange(const QJsonObject &data) {
  m_lyrics.clear();
  m_lyricsList.clear();
  m_hasTranslation = false;

  qDebug() << "=== handleLyricChange ===";
  qDebug() << "Has lrcData:" << data.contains("lrcData");
  qDebug() << "Has yrcData:" << data.contains("yrcData");

  // 优先使用 yrcData 进行逐字计时，回退到 lrcData
  QJsonArray lyricArray;
  bool usingYrc = false;

  if (data.contains("yrcData")) {
    lyricArray = data["yrcData"].toArray();
    if (!lyricArray.isEmpty()) {
      usingYrc = true;
      qDebug() << "Using yrcData with" << lyricArray.size() << "lines";
    }
  }

  if (!usingYrc && data.contains("lrcData")) {
    lyricArray = data["lrcData"].toArray();
    qDebug() << "Using lrcData with" << lyricArray.size() << "lines";
  }

  for (const auto &item : lyricArray) {
    QJsonObject line = item.toObject();

    double time = 0;
    QString fullText;
    QString translatedLyric;
    QVector<SPlayerClient::WordInfo> words;

    // SPlayer 歌词格式使用 startTime（以毫秒为单位）
    if (line.contains("startTime"))
      time = line["startTime"].toDouble() / 1000.0; // 将毫秒转换为秒

    if (line.contains("text")) {
      fullText = line["text"].toString();
    } else if (line.contains("lyric")) {
      fullText = line["lyric"].toString();
    }

    if (line.contains("translatedLyric")) {
      translatedLyric = line["translatedLyric"].toString();
      if (!translatedLyric.isEmpty()) {
        m_hasTranslation = true;
      }
    }

    // 只有逐字歌词才解析词级时间
    if (line.contains("words")) {
      QJsonArray wordsArray = line["words"].toArray();
      for (const auto &wordItem : wordsArray) {
        QJsonObject wordObj = wordItem.toObject();
        if (wordObj.contains("word")) {
          const QString wordText = wordObj["word"].toString();
          if (fullText.isEmpty()) {
            fullText += wordText;
          } else if (!line.contains("text") && !line.contains("lyric")) {
            fullText += wordText;
          }

          if (usingYrc) {
            WordInfo wordInfo;
            wordInfo.word = wordText;
            wordInfo.startTime = wordObj["startTime"].toDouble() / 1000.0;
            wordInfo.endTime = wordObj["endTime"].toDouble() / 1000.0;
            words.append(wordInfo);
          }
        }
      }
    }

    // 调试第一行以验证结构
    if (m_lyrics.size() == 0) {
      qDebug() << "First lyric line raw:" << line;
      qDebug() << "Parsed time:" << time << "fullText:" << fullText;
      qDebug() << "Word count:" << words.size();
    }

    m_lyrics.append({time, fullText, translatedLyric, words});

    // 填充 m_lyricsList
    QVariantMap lineMap;
    lineMap["time"] = time;
    lineMap["text"] = fullText;
    lineMap["translatedLyric"] = translatedLyric;
    lineMap["index"] = m_lyrics.size() - 1;
    QVariantList wordsList;
    for (const auto &word : words) {
      QVariantMap wordMap;
      wordMap["startTime"] = word.startTime;
      wordMap["endTime"] = word.endTime;
      wordMap["word"] = word.word;
      wordsList.append(wordMap);
    }
    lineMap["words"] = wordsList;
    m_lyricsList.append(lineMap);
  }

  qDebug() << "Loaded" << m_lyrics.size() << "lyric lines.";
  
  // 切歌或重新加载歌词时，重置所有状态
  m_currentLineIndex = -1;
  m_currentLyric = "";
  m_currentTime = 0;
  m_baseTime = 0;
  m_baseTimestamp = 0;
  emit progressChanged();
  
  updateCurrentLyricLine();
  m_lastLyricUpdateTimestamp = QDateTime::currentMSecsSinceEpoch();
  emit lyricChanged();
}

void SPlayerClient::updateCurrentLyricLine() {
  if (m_lyrics.isEmpty()) {
    if (!m_currentLyric.isEmpty()) {
      m_currentLyric = "";
      emit lyricChanged();
    }
    return;
  }

  int index = -1;
  int startSearch = 0;
  
  if (m_currentLineIndex >= 0 && m_currentLineIndex < m_lyrics.size()) {
      // 如果当前时间超过当前行，则从那里开始
      if (m_lyrics[m_currentLineIndex].time <= m_currentTime) {
          startSearch = m_currentLineIndex;
      }
  }

  for (int i = startSearch; i < m_lyrics.size(); ++i) {
    if (m_lyrics[i].time <= m_currentTime) {
      index = i;
    } else {
      break;
    }
  }

  QString newLine = "";
  if (index >= 0 && index < m_lyrics.size()) {
    newLine = m_lyrics[index].text;
  }

  if (newLine != m_currentLyric || index != m_currentLineIndex) {
    m_currentLyric = newLine;
    m_currentLineIndex = index;
    emit lyricChanged();
  }
}

void SPlayerClient::activateWindow() {
  emit requestActivate();
}

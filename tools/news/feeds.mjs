// Источники новостей для утренней страницы. Без ИИ: RSS-ленты и новости Steam.
// sec — раздел по умолчанию: cg · industry · releases · updates · hype. ИИ может переставить пункт в другой раздел.
// Лента не открылась — просто пропускается, остальные работают.

export const FEEDS = [
  // CG и 3D
  { name: 'CG Channel', url: 'https://www.cgchannel.com/feed/', sec: 'cg' },
  { name: '80 Level', url: 'https://80.lv/feed', sec: 'cg' },
  { name: 'BlenderNation', url: 'https://www.blendernation.com/feed/', sec: 'cg' },
  { name: 'CGPress', url: 'https://www.cgpress.org/feed', sec: 'cg' },
  { name: 'Digital Production', url: 'https://digitalproduction.com/feed/', sec: 'cg' },
  { name: 'Creative Bloq', url: 'https://www.creativebloq.com/feeds/tag/3d', sec: 'cg' },
  // Игровая индустрия
  { name: 'Shazoo', url: 'https://shazoo.ru/feed/rss', sec: 'industry' },
  { name: 'DTF', url: 'https://dtf.ru/rss/all', sec: 'industry' },
  { name: 'StopGame', url: 'https://rss.stopgame.ru/rss_news.xml', sec: 'industry' },
  { name: 'PC Gamer', url: 'https://www.pcgamer.com/rss/', sec: 'industry' },
  { name: 'GamesIndustry.biz', url: 'https://www.gamesindustry.biz/feed', sec: 'industry' },
  { name: 'Game Developer', url: 'https://www.gamedeveloper.com/rss.xml', sec: 'industry' },
  { name: 'Eurogamer', url: 'https://www.eurogamer.net/feed', sec: 'industry' },
  // Релизы недели
  { name: 'GameGrin', url: 'https://www.gamegrin.com/rss/news/', sec: 'releases' },
  // Хайп дня
  { name: 'iXBT', url: 'https://www.ixbt.com/export/news.rss', sec: 'hype' },
  { name: 'TechCrunch', url: 'https://techcrunch.com/feed/', sec: 'hype' },
];

// Обновления игр — официальные объявления в Steam (JSON, без ключа).
export const STEAM_GAMES = [
  { app: 570, name: 'Dota 2', dota: true },
  { app: 2357570, name: 'Overwatch 2' },
  { app: 2767030, name: 'Marvel Rivals' },
  { app: 1422450, name: 'Deadlock' },
  { app: 2073850, name: 'THE FINALS' },
  { app: 1091500, name: 'Cyberpunk 2077' },
  { app: 1808500, name: 'ARC Raiders' },
  { app: 1172470, name: 'Apex Legends' },
];

export const steamUrl = (app) =>
  `https://api.steampowered.com/ISteamNews/GetNewsForApp/v2/?appid=${app}&count=8&maxlength=400&feeds=steam_community_announcements`;

export const SECTIONS = [
  { id: 'cg', title: 'CG и 3D', max: 8 },
  { id: 'industry', title: 'Игровая индустрия', max: 8 },
  { id: 'releases', title: 'Выходит на этой неделе', max: 6 },
  { id: 'updates', title: 'Обновления игр', max: 6 },
  { id: 'hype', title: 'Хайп дня', max: 6 },
];

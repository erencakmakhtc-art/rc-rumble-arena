/// Uygulamanin hangi ana ekranda oldugunu belirtir.
/// modes: bolum secim listesi.
/// game: Sekil Avi bolumu (ilk/ana oyun).
/// mini: diger bolumlerden biri (hangisi oldugu GameController.activeMode'da).
enum AppScreen { signup, home, modes, game, mini, board }

/// Bir asama (stage) icindeki oyun fazi.
/// idle: hicbir oyun baslamamisken (home/signup ekranlarinda).
/// intro: "nasil oynanir" tanitim karti (oyuncu onayi bekleniyor).
/// announce: "Bu isaretin 6 tanesini bul" tanitim karti (1.5 sn).
/// count: 3-2-1 geri sayimi.
/// play: oyuncu izgarada arama yapiyor, sure isliyor.
/// done: asama tamamlandi, bir sonraki asamaya gecis bekleniyor.
/// final_: 3 asama da tamamlandi, sonuc karti gosteriliyor.
enum GamePhase { idle, intro, announce, count, play, done, final_ }

/// Dunya siralamasi hesaplama animasyonunun asamasi.
enum RankPhase { none, calc, done }

/// Skor tablosu sekmesi.
enum BoardTab { solo, country }

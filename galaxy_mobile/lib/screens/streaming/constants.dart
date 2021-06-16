class StreamConstants {
  static const NO_VIDEO_OPTION_VALUE = -1;
  static const VIDEO_240P_OPTION_VALUE = 11;
  static const VIDEO_360P_OPTION_VALUE = 1;
  static const VIDEO_720P_OPTION_VALUE = 16;

  static const videos_options = [
    {"key": 1, "text": '240p', "value": VIDEO_240P_OPTION_VALUE},
    {"key": 2, "text": '360p', "value": VIDEO_360P_OPTION_VALUE},
    {"key": 3, "text": '720p', "value": VIDEO_720P_OPTION_VALUE},
    {"key": 4, "text": 'NoVideo', "value": NO_VIDEO_OPTION_VALUE},
  ];

  static const audiog_options = [
    {
      "key": 101,
      "value": 101,
      "text": 'Workshop',
      "disabled": true,
      "icon": "tags",
      "selected": true
    },
    {"key": 2, "value": 2, "flag": 'il', "text": 'Hebrew'},
    {"key": 3, "value": 3, "flag": 'ru', "text": 'Russian'},
    {"key": 4, "value": 4, "flag": 'us', "text": 'English'},
    {"key": 6, "value": 6, "flag": 'es', "text": 'Spanish'},
    {"key": 5, "value": 5, "flag": 'fr', "text": 'French'},
    {"key": 8, "value": 8, "flag": 'it', "text": 'Italian'},
    {"key": 7, "value": 7, "flag": 'de', "text": 'German'},
    {
      "key": 100,
      "value": 100,
      "text": 'Source',
      "disabled": true,
      "icon": "tags",
      "selected": true
    },
    {"key": 'he', "value": 15, "flag": 'il', "text": 'Hebrew'},
    {"key": 'ru', "value": 23, "flag": 'ru', "text": 'Russian'},
    {"key": 'en', "value": 24, "flag": 'us', "text": 'English'},
    {"key": 'es', "value": 26, "flag": 'es', "text": 'Spanish'},
    {"key": 'fr', "value": 25, "flag": 'fr', "text": 'French'},
    {"key": 'it', "value": 28, "flag": 'it', "text": 'Italian'},
    {"key": 'de', "value": 27, "flag": 'de', "text": 'German'},
    {"key": 'tr', "value": 42, "flag": 'tr', "text": 'Turkish'},
    {"key": 'pt', "value": 41, "flag": 'pt', "text": 'Portuguese'},
    {"key": 'bg', "value": 43, "flag": 'bg', "text": 'Bulgarian'},
    {"key": 'ka', "value": 44, "flag": 'ge', "text": 'Georgian'},
    {"key": 'ro', "value": 45, "flag": 'ro', "text": 'Romanian'},
    {"key": 'hu', "value": 46, "flag": 'hu', "text": 'Hungarian'},
    {"key": 'sv', "value": 47, "flag": 'se', "text": 'Swedish'},
    {"key": 'lt', "value": 48, "flag": 'lt', "text": 'Lithuanian'},
    {"key": 'hr', "value": 49, "flag": 'hr', "text": 'Croatian'},
    {"key": 'ja', "value": 50, "flag": 'jp', "text": 'Japanese'},
    {"key": 'sl', "value": 51, "flag": 'si', "text": 'Slovenian'},
    {"key": 'pl', "value": 52, "flag": 'pl', "text": 'Polish'},
    {"key": 'no', "value": 53, "flag": 'no', "text": 'Norwegian'},
    {"key": 'lv', "value": 54, "flag": 'lv', "text": 'Latvian'},
    {"key": 'ua', "value": 55, "flag": 'ua', "text": 'Ukrainian'},
    {"key": 'nl', "value": 56, "flag": 'nl', "text": 'Dutch'},
    {"key": 'cn', "value": 57, "flag": 'cn', "text": 'Chinese'},
    {"key": 'et', "value": 58, "flag": 'et', "text": 'Amharic'},
    {"key": 'in', "value": 59, "flag": 'in', "text": 'Hindi'},
    {"key": 'ir', "value": 60, "flag": 'ir', "text": 'Persian'},
    {
      "key": 99,
      "value": 99,
      "text": 'Special',
      "disabled": true,
      "icon": "tags",
      "selected": true
    },
    {"key": 'heru', "value": 10, "text": 'Heb-Rus'},
    {"key": 'heen', "value": 17, "text": 'Heb-Eng'},
  ];

  static const gxycol = [0, 201, 203, 202, 204];

  static const trllang = {
    "Hebrew": 301,
    "Russian": 302,
    "English": 303,
    "Spanish": 304,
    "French": 305,
    "Italian": 306,
    "German": 307,
    "Turkish": 308,
    "Portuguese": 309,
    "Bulgarian": 310,
    "Georgian": 311,
    "Romanian": 312,
    "Hungarian": 313,
    "Swedish": 314,
    "Lithuanian": 315,
    "Croatian": 316,
    "Japanese": 317,
    "Slovenian": 318,
    "Polish": 319,
    "Norwegian": 320,
    "Latvian": 321,
    "Ukrainian": 322,
    "Dutch": 323,
    "Chinese": 324,
    "Amharic": 325,
    "Hindi": 326,
    "Persian": 327,
    "Heb-Eng": 303,
    "Heb-Rus": 302,
  };
}

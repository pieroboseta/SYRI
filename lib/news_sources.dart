class RegionalNewsSource {
  final String name;
  final String url;
  final String country;

  const RegionalNewsSource(this.name, this.url, this.country);
}

const regionalNewsSources = <RegionalNewsSource>[
  RegionalNewsSource(
    'Star Plus TV',
    'https://www.starplus-tv.com/feed/',
    'Shqipëri',
  ),
  RegionalNewsSource('RTSH', 'https://rtsh.al/feed/', 'Shqipëri'),
  RegionalNewsSource(
    'BalkanWeb',
    'https://www.balkanweb.com/feed/',
    'Shqipëri',
  ),
  RegionalNewsSource('KALLXO', 'https://kallxo.com/feed/', 'Kosovë'),
  RegionalNewsSource('Telegrafi', 'https://telegrafi.com/feed/', 'Kosovë'),
  RegionalNewsSource('Reporteri', 'https://reporteri.net/feed/', 'Kosovë'),
  RegionalNewsSource(
    'Gazeta Express',
    'https://gazetaexpress.com/feed/',
    'Kosovë',
  ),
  RegionalNewsSource(
    'Portalb',
    'https://portalb.mk/category/maqedoni/feed/',
    'Maqedonia e Veriut',
  ),
  RegionalNewsSource('Alsat', 'https://alsat.mk/feed/', 'Maqedonia e Veriut'),
  RegionalNewsSource('Koha Javore', 'https://kohajavore.me/feed/', 'Mali i Zi'),
  RegionalNewsSource('Ul-info', 'https://www.ul-info.com/feed/', 'Mali i Zi'),
];

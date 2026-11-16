# Seasonal design references — revision 9

The resort is fictional and Caribbean-inspired. Its temperatures, three-day months and seaweed arrival quantities are game-design defaults, not forecasts or a simulation of a particular real beach.

Miami-Dade County describes a March–October sargassum season and explains that seasonal winds and currents transport it toward the Caribbean and Gulf. It also describes repeated shoreline arrivals and daily cleanup. This supports a visible accumulation and cleanup loop rather than a permanent brown beach texture. [County sargassum guidance](https://www.miamidade.gov/global/recreation/Sargassum.page)

NOAA's overview identifies a summer peak for the Caribbean source. The game therefore uses greater summer arrival pressure, with lower spring/autumn pressure and no new seasonal arrivals in its winter months; existing buildup still needs to clear. Actual arrival timing and severity vary. [NOAA overview](https://www.aoml.noaa.gov/?p=10479), [NOAA sargassum FAQ](https://coastwatch.noaa.gov/cwn/news/2023-04-04/sargassum-faq.html)

The temperature curve is deliberately authored: monthly mean values range from 24°C in January to 29°C in July/August, with a modest ±2°C daily cycle. These numbers are not presented as measured climate normals. Calendar day 1 starts in March, each month lasts three operating days, and each existing 240-second operating day spans 24 game hours starting at 06:00. Save/load derives date, light and temperature from the saved simulation day and second.

import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:amap_location/amap_location.dart';
import 'package:amap_location/amap_location_option.dart';
import 'package:coolweather/utils/image_utils.dart';
import 'package:coolweather/utils/unit_convert_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:quiver/strings.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'bean/daily.dart';
import 'bean/focus_district_list_bean.dart';
import 'bean/hourly.dart';
import 'bean/minutely.dart';
import 'bean/realtime.dart';
import 'bean/weather_bean.dart';
import 'data/global.dart';
import 'data/unit_model.dart';
import 'utils/date_utils.dart';
import 'utils/translation_utils.dart';
import 'views/rainfall_line.dart';
import 'views/sunrise_sunset_line.dart';
import 'views/temperature_line.dart';

class WeatherDetailPage extends StatefulWidget {
  final District district;

  final Function setWeatherData;

  final Function setLocation;

  final double height;

  WeatherDetailPage(
      this.district, this.setLocation, this.setWeatherData, this.height);

  @override
  State<StatefulWidget> createState() {
    return _WeatherDetailPageState(district);
  }
}

class _WeatherDetailPageState extends State<WeatherDetailPage> {
  District district;

  WeatherBean weatherBean;

  Result result;

  Realtime realtime;

  Minutely minutely;

  Hourly hourly;

  Daily daily;

  _WeatherDetailPageState(this.district);

  @override
  void initState() {
    super.initState();

    if (district.latitude == -1 && district.longitude == -1) {
      _checkPermission();
    } else {
      _queryWeather(district.longitude, district.latitude);
    }
  }

  void _checkPermission() async {
    await PermissionHandler().requestPermissions([PermissionGroup.location]);
    PermissionStatus status = await PermissionHandler()
        .checkPermissionStatus(PermissionGroup.location);
    if (status == PermissionStatus.granted) {
      _initLocation();
    } else {
      Fluttertoast.showToast(
        toastLength: Toast.LENGTH_LONG,
        msg: "为了更好的为您提供本地天气服务，请在设置中给予定位权限，然后再次打开APP",
      );
      await PermissionHandler().openAppSettings();
    }
  }

  // 定位
  _initLocation() async {
    bool result = await AMapLocationClient.startup(
        AMapLocationOption(onceLocation: true));

    if (result) {
      AMapLocation aMapLocation = await AMapLocationClient.getLocation(true);
      if (aMapLocation.district == null ||
          aMapLocation.latitude == null ||
          aMapLocation.longitude == null) {
        return;
      }

      district = new District(
          aMapLocation.district, aMapLocation.latitude, aMapLocation.longitude);
      Global.locationDistrict = district;
      widget.setLocation(district);
      _queryWeather(district.longitude, district.latitude);

      SharedPreferences prefs = await SharedPreferences.getInstance();
      String locationDistrictJson = jsonEncode(district.toJson());
      prefs.setString('location_district', locationDistrictJson);
    }
  }

  @override
  Widget build(BuildContext context) {
    return weatherDetailLayout(context);
  }

  Widget weatherDetailLayout(BuildContext context) {
    // 一加5 1080 / 731.4285714285714 = 1.4765625
    // 红米note2 1080 / 640.0 = 1.6875
    if (weatherBean != null) {
      return Theme(
        data: Theme.of(context)
            .copyWith(accentColor: Color.fromARGB(255, 51, 181, 229)),
        child: RefreshIndicator(
          onRefresh: () =>
              _queryWeather(district.longitude, district.latitude, force: true),
          child: Theme(
            data: Theme.of(context).copyWith(accentColor: Colors.white),
            child: ListView(
              children: <Widget>[
                SizedBox(
                  height: widget.height,
                  width: double.infinity,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      _tempLayout(),
                      _weatherLayout(),
                      _tipsLayout(),
                      _rainTendencyLayout(),
                      _forecastLayout(),
                    ],
                  ),
                ),
                _tempLineLayout(),
                _dividerLayout(edgeInsets: EdgeInsets.only(top: 30)),
                _sunriseSunsetLayout(),
                _dividerLayout(),
                _moreInfLayout(),
                _dataFromLayout(),
              ],
            ),
          ),
        ),
      );
    } else {
      return Center();
    }
  }

  Widget _tempLayout() {
    return Consumer<UnitModel>(
      builder: (context, unitModel, _) {
        double temperature = realtime.temperature;
        if (unitModel.temperature == TemperatureUnit.fahrenheit) {
          temperature = UnitConvertUtils.celsiusToFahrenheit(temperature);
        }
        return Padding(
          padding: EdgeInsets.only(left: 28),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              Text(
                '${temperature.toStringAsFixed(0)}${temperatureUnitList.elementAt(unitModel.temperature.index).unitShow}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 60,
                  fontWeight: FontWeight.w300,
                ),
              )
            ],
          ),
        );
      },
    );
  }

  Widget _weatherLayout() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 28),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: <Widget>[
          Text(
            Translation.getWeatherDesc(
                realtime.skycon, realtime.precipitation.local.intensity),
            style: TextStyle(color: Colors.white, fontSize: 18),
          )
        ],
      ),
    );
  }

  Widget _tipsLayout() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 28, vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: <Widget>[
          Text(
            result.forecast_keypoint,
            style: TextStyle(
                color: Colors.white70,
                fontSize: 10,
                decoration: TextDecoration.none),
          )
        ],
      ),
    );
  }

  Widget _rainTendencyLayout() {
    bool rain = false;
    minutely.precipitation_2h.forEach((rainfall) {
      if (rainfall > 0) {
        rain = true;
      }
    });

    return rain
        ? Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: RainfallLine(minutely.precipitation_2h),
          )
        : Center();
  }

  Widget _forecastLayout() {
    List<Widget> forecastRow = new List();
    int length = daily.skycon.length;
    for (int i = 0; i < length; i++) {
      Skycon skycon = daily.skycon.elementAt(i);
      double intensity = daily.precipitation.elementAt(i).max;
      DateTime dateTime = DateTime.parse(skycon.date);
      ImageIcon weatherIcon = _getWeatherIcon(skycon.value);

      forecastRow.add(Column(
        children: <Widget>[
          _textLayout(DateUtils.getWhichDay(dateTime.weekday - 1)),
          _textLayout('${dateTime.month}' + '月' + '${dateTime.day}' + '日'),
          Padding(
            padding: EdgeInsets.only(top: 8, bottom: 2),
            //child: Icon(imageIcon, color: Colors.white),
            child: weatherIcon,
          ),
          _textLayout(Translation.getWeatherDesc(skycon.value, intensity)),
        ],
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
      ));
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(12, 30, 12, 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: forecastRow,
      ),
    );
  }

  Widget _textLayout(String content) {
    return Text(content,
        style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            decoration: TextDecoration.none));
  }

  ImageIcon _getWeatherIcon(String weather) {
    return ImageIcon(
      AssetImage(ImageUtils.getWeatherIconUri(weather)),
      size: 22,
      color: Colors.white,
    );
  }

  // 气温折线图
  Widget _tempLineLayout() {
    List<Temp> tempList = List();

    var forecast = daily.temperature;
    for (int i = 0; i < forecast.length; i++) {
      tempList.add(Temp(forecast.elementAt(i).max, forecast.elementAt(i).min));
    }
    return Padding(
      padding: EdgeInsets.only(top: 5, bottom: 20),
      child: TemperatureLine(tempList),
    );
  }

  // 日出日落
  Widget _sunriseSunsetLayout() {
    return SunriseSunsetLine(daily.astro.elementAt(0));
  }

  //  更多信息
  Widget _moreInfLayout() {
    return Consumer<UnitModel>(
      builder: (context, unitModel, _) {
        double temperature = realtime.temperature;
        if (unitModel.temperature == TemperatureUnit.fahrenheit) {
          temperature = UnitConvertUtils.celsiusToFahrenheit(temperature);
        }

        double windSpeed = realtime.wind.speed;
        String windSpeedDesc;
        // 如果风力单位是"级"，则单位显示在主内容上
        String windUnit = '';

        if (unitModel.wind == WindUnit.grade) {
          windSpeedDesc = UnitConvertUtils.kmhToGrade(windSpeed) +
              windUnitList.elementAt(unitModel.wind.index).unitEN;
        } else {
          if (unitModel.wind == WindUnit.m_s) {
            windSpeed = UnitConvertUtils.kmhToMs(windSpeed);
          } else if (unitModel.wind == WindUnit.ft_s) {
            windSpeed = UnitConvertUtils.kmhToFts(windSpeed);
          } else if (unitModel.wind == WindUnit.mph) {
            windSpeed = UnitConvertUtils.kmhToMph(windSpeed);
          } else if (unitModel.wind == WindUnit.kts) {
            windSpeed = UnitConvertUtils.kmhToKts(windSpeed);
          }
          windSpeedDesc = windSpeed.toStringAsFixed(1);
          windUnit = windUnitList.elementAt(unitModel.wind.index).unitEN;
        }

        double visibility = realtime.visibility;
        if (unitModel.visibility == VisibilityUnit.mi) {
          visibility = UnitConvertUtils.kmToMi(visibility);
        }

        double pres = realtime.pres;
        if (unitModel.airPressure == AirPressureUnit.hPa) {
          pres = UnitConvertUtils.paToHpa(pres);
        } else if (unitModel.airPressure == AirPressureUnit.mmHg) {
          pres = UnitConvertUtils.paToMmHg(pres);
        } else if (unitModel.airPressure == AirPressureUnit.inHg) {
          pres = UnitConvertUtils.paToInHg(pres);
        }

        return Column(
          children: <Widget>[
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: <Widget>[
                  Padding(
                    padding: EdgeInsets.only(top: 15),
                    child: Row(
                      children: <Widget>[
                        getWidget(
                            '空气质量', Translation.getAqiDesc(realtime.aqi), ''),
                        getWidget('PM2.5', realtime.pm25.toString(), ''),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: 25),
                    child: Row(
                      children: <Widget>[
                        getWidget(
                            Translation.getWindDir(realtime.wind.direction),
                            windSpeedDesc,
                            windUnit),
                        getWidget(
                            '体感温度',
                            temperature.toStringAsFixed(0) +
                                temperatureUnitList
                                    .elementAt(unitModel.temperature.index)
                                    .unitShow,
                            ''),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: 25),
                    child: Row(
                      children: <Widget>[
                        getWidget(
                            '湿度',
                            (realtime.humidity * 100 + 0.5).toInt().toString(),
                            '%'),
                        getWidget(
                            '能见度',
                            visibility.toStringAsFixed(1),
                            visibilityUnitList
                                .elementAt(unitModel.visibility.index)
                                .unitEN),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: 25),
                    child: Row(
                      children: <Widget>[
                        getWidget('紫外线', realtime.ultraviolet.desc, ''),
                        getWidget(
                            '气压',
                            pres.toStringAsFixed(0),
                            airPressureUnitList
                                .elementAt(unitModel.airPressure.index)
                                .unitEN),
                      ],
                    ),
                  ),
                ],
              ),
            )
          ],
        );
      },
    );
  }

  Widget getWidget(String title, String value, String unit) {
    return Expanded(
      flex: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title,
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
              )),
          Padding(
            padding: EdgeInsets.only(top: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(value,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    )),
                Padding(
                  padding: EdgeInsets.only(left: 2),
                  child: Text(unit,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      )),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  // 数据来源
  Widget _dataFromLayout() {
    return Padding(
      padding: EdgeInsets.only(top: 10),
      child: SizedBox(
        width: double.infinity,
        height: 40,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Text(
              '天气数据来源于彩云天气网',
              style: TextStyle(color: Colors.white24, fontSize: 10),
            )
          ],
        ),
      ),
    );
  }

  // 分割线
  Widget _dividerLayout({EdgeInsets edgeInsets}) {
    return Padding(
      padding: edgeInsets != null ? edgeInsets : EdgeInsets.all(0),
      child: Divider(
        thickness: 1,
        color: Colors.white12,
      ),
    );
  }

  // 查询天气信息
  Future<void> _queryWeather(double longitude, double latitude,
      {bool force}) async {
    Future<SharedPreferences> future = SharedPreferences.getInstance();
    await future.then((prefs) async {
      String json = prefs.getString(district.name);
      WeatherBean bean;
      if (!isEmpty(json) && (force == null || !force)) {
        Map map = jsonDecode(json);
        bean = WeatherBean.fromJson(map);
        if (DateUtils.currentTimeMillis() - bean.server_time * 1000 >
            1000 * 60 * 15) {
          bean = null;
        }
      }

      if (bean == null) {
        String url = 'https://api.caiyunapp.com/v2/' +
            Global.caiYunKey +
            '/$longitude,$latitude/' +
            'weather.json?dailysteps=6&unit=metric:v1';

        print(url);

        var httpClient = new HttpClient();
        try {
          var request = await httpClient.getUrl(Uri.parse(url));
          var response = await request.close();
          if (response.statusCode == HttpStatus.ok) {
            json = await response.transform(utf8.decoder).join();
            Map map = jsonDecode(json);
            bean = WeatherBean.fromJson(map);

            future.then((prefs) {
              prefs.setString(district.name, json);
            });
          }
        } catch (ignore) {}
      }

      setState(() {
        weatherBean = bean;
        result = weatherBean.result;
        realtime = result.realtime;
        minutely = result.minutely;
        hourly = result.hourly;
        daily = result.daily;
        widget.setWeatherData(weatherBean);
      });
    });
  }
}

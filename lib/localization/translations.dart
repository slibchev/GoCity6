import 'app_language.dart';

class AppTranslations {
 
  static AppLanguage currentLanguage = AppLanguage.bulgarian;

  static String get chooseLanguage {
    if (currentLanguage == AppLanguage.english) {
      return 'Choose language';
    }
    return 'Избери език';
  }

  static String get english {
    return 'English';
  }

  static String get bulgarian {
    return 'Български';
  }

  static String get orderButton {
    if (currentLanguage == AppLanguage.english) {
      return 'Book a ride';
    }
    return 'Поръчай';
  }

  static String get comfortText {
    if (currentLanguage == AppLanguage.english) {
      return '6 seats • More comfort • More freedom';
    }
    return '6 места • Повече комфорт • Повече свобода';
  }
  static String get welcomeText {
  if (currentLanguage == AppLanguage.english) {
    return 'Welcome to GoCity6';
  }
  return 'Добре дошли в GoCity6';
}
static String get pickupLocation {
  if (currentLanguage == AppLanguage.english) {
    return 'Pickup location';
  }
  return 'От къде?';
}

static String get destinationLocation {
  if (currentLanguage == AppLanguage.english) {
    return 'Destination';
  }
  return 'До къде?';
}

static String get passengers {
  if (currentLanguage == AppLanguage.english) {
    return 'Passengers';
  }
  return 'Брой пътници';
}
static String get rideType {
  if (currentLanguage == AppLanguage.english) {
    return 'Ride type';
  }
  return 'Тип курс';
}

static String get cityRide {
  if (currentLanguage == AppLanguage.english) {
    return 'City';
  }
  return 'Градско';
}

static String get intercityRide {
  if (currentLanguage == AppLanguage.english) {
    return 'Intercity';
  }
  return 'Извънградско';
}

static String get payment {
  if (currentLanguage == AppLanguage.english) {
    return 'Payment';
  }
  return 'Плащане';
}

static String get cash {
  if (currentLanguage == AppLanguage.english) {
    return 'Cash';
  }
  return 'В брой';
}

static String get card {
  if (currentLanguage == AppLanguage.english) {
    return 'Card';
  }
  return 'Карта';
}

static String get voucher {
  if (currentLanguage == AppLanguage.english) {
    return 'Voucher';
  }
  return 'Ваучер';
}

static String get estimatedPrice {
  if (currentLanguage == AppLanguage.english) {
    return 'Estimated price: calculation pending';
  }
  return 'Ориентировъчна цена: предстои изчисление';
}

static String get confirmRide {
  if (currentLanguage == AppLanguage.english) {
    return 'Confirm ride';
  }
  return 'Потвърди заявката';
}
static String get pickupRequired {
  if (currentLanguage == AppLanguage.english) {
    return 'Please enter pickup location';
  }
  return 'Моля въведете начална точка';
}


static String get destinationRequired {
  if (currentLanguage == AppLanguage.english) {
    return 'Please enter destination';
  }
  return 'Моля въведете крайна точка';
}


static String get rideAccepted {
  if (currentLanguage == AppLanguage.english) {
    return 'Ride request accepted!';
  }
  return 'Заявката е приета успешно!';
}
static String get rideRequestSent {
  if (currentLanguage == AppLanguage.english) {
    return 'Ride request sent';
  }

  return 'Заявката за курс е изпратена';
}

static String get waitingForDriverConfirmation {
  if (currentLanguage == AppLanguage.english) {
    return 'Waiting for driver confirmation';
  }

  return 'Очаква се потвърждение от шофьора';
}
static String get rideSummary {
  if (currentLanguage == AppLanguage.english) {
    return 'Ride summary';
  }
  return 'Обобщение на курса';
}


static String get vehicle {
  if (currentLanguage == AppLanguage.english) {
    return 'Vehicle';
  }
  return 'Автомобил';
}


static String get vehicleInfo {
  if (currentLanguage == AppLanguage.english) {
    return 'GoCity6 - 6 seats';
  }
  return 'GoCity6 - 6 места';
}


static String get luggage {
  if (currentLanguage == AppLanguage.english) {
    return 'Luggage';
  }
  return 'Багаж';
}


static String get luggageInfo {
  if (currentLanguage == AppLanguage.english) {
    return 'Not selected';
  }
  return 'Не е избран';
}


static String get arrivalTime {
  if (currentLanguage == AppLanguage.english) {
    return 'Estimated arrival';
  }
  return 'Очаквано пристигане';
}


static String get calculating {
  if (currentLanguage == AppLanguage.english) {
    return 'Calculating...';
  }
  return 'Изчислява се...';
}


static String get priceLabel {
  if (currentLanguage == AppLanguage.english) {
    return 'Estimated price';
  }
  return 'Ориентировъчна цена';
}
static String get from {
  if (currentLanguage == AppLanguage.english) {
    return 'From';
  }
  return 'От';
}


static String get to {
  if (currentLanguage == AppLanguage.english) {
    return 'To';
  }
  return 'До';
}


static String get passengersLabel {
  if (currentLanguage == AppLanguage.english) {
    return 'Passengers';
  }
  return 'Пътници';
}


static String get paymentMethod {
  if (currentLanguage == AppLanguage.english) {
    return 'Payment';
  }
  return 'Начин на плащане';
}
static String get backButton {
  if (currentLanguage == AppLanguage.english) {
    return 'Back';
  }
  return 'Назад';
}
static String get slogan {
  if (currentLanguage == AppLanguage.english) {
    return 'Be 6 – Be Together';
  }
  return 'Be 6 - Пътувайте заедно';
}
static String get routeCalculationFailed {
  if (currentLanguage == AppLanguage.english) {
    return 'Could not calculate the route. Please try again.';
  }
  return 'Маршрутът не можа да бъде изчислен. Моля, опитайте отново.';
}
static String get distance {
  if (currentLanguage == AppLanguage.english) {
    return 'Distance';
  }
  return 'Разстояние';
}

static String get estimatedDuration {
  if (currentLanguage == AppLanguage.english) {
    return 'Estimated duration';
  }
  return 'Ориентировъчно време';
}

static String get minutes {
  if (currentLanguage == AppLanguage.english) {
    return 'min';
  }
  return 'мин';
}

}

import 'app_language.dart';
import 'package:flutter/foundation.dart';

class AppTranslations {
  static final ValueNotifier<AppLanguage> languageNotifier = ValueNotifier(
    AppLanguage.bulgarian,
  );

  static AppLanguage get currentLanguage => languageNotifier.value;

  static set currentLanguage(AppLanguage language) {
    languageNotifier.value = language;
  }

  static String get chooseLanguage {
    if (currentLanguage == AppLanguage.english) {
      return 'Choose language';
    }
    return 'Избери език';
  }

  static String get favorites =>
      currentLanguage == AppLanguage.english ? 'Favorites' : 'Любими';

  static String get favoriteAdd =>
      currentLanguage == AppLanguage.english ? 'Add' : 'Добави';

  static String get favoriteEmptyTitle => currentLanguage == AppLanguage.english
      ? 'No favorite addresses yet'
      : 'Нямате любими адреси';

  static String get favoriteEmptyDescription =>
      currentLanguage == AppLanguage.english
      ? 'Add frequently used addresses like Home, Work, or another favorite address.'
      : 'Добавете често използвани адреси като Дом, Работа или друг любим адрес.';

  static String get favoriteEdit =>
      currentLanguage == AppLanguage.english ? 'Edit' : 'Редактирай';

  static String get favoriteDelete =>
      currentLanguage == AppLanguage.english ? 'Delete' : 'Изтрий';

  static String get favoriteDeleteConfirmationTitle =>
      currentLanguage == AppLanguage.english
      ? 'Delete favorite address'
      : 'Изтриване на любим адрес';

  static String favoriteDeleteConfirmationMessage(String name) =>
      currentLanguage == AppLanguage.english
      ? 'Are you sure you want to delete "$name"?'
      : 'Сигурни ли сте, че искате да изтриете "$name"?';

  static String get favoriteCancel =>
      currentLanguage == AppLanguage.english ? 'Cancel' : 'Отказ';

  static String get favoriteEditDialogTitle =>
      currentLanguage == AppLanguage.english
      ? 'Edit address'
      : 'Редактиране на адрес';

  static String get favoriteAddDialogTitle =>
      currentLanguage == AppLanguage.english
      ? 'Add favorite address'
      : 'Добавяне на любим адрес';

  static String get favoriteNameLabel =>
      currentLanguage == AppLanguage.english ? 'Name' : 'Име';

  static String get favoriteNameHint => currentLanguage == AppLanguage.english
      ? 'Home, Work...'
      : 'Дом, Работа...';

  static String get favoriteAddressLabel =>
      currentLanguage == AppLanguage.english ? 'Address' : 'Адрес';

  static String get favoriteAddressHint =>
      currentLanguage == AppLanguage.english
      ? 'Start typing an address'
      : 'Започнете да въвеждате адрес';

  static String get favoriteNameValidation =>
      currentLanguage == AppLanguage.english
      ? 'Enter a name for this address'
      : 'Въведете име на адреса';

  static String get favoriteAddressValidation =>
      currentLanguage == AppLanguage.english
      ? 'Select an address from the suggestions'
      : 'Изберете адрес от предложенията';

  static String get favoriteSave =>
      currentLanguage == AppLanguage.english ? 'Save' : 'Запази';

  static String get destinationFavoritesEmpty =>
      currentLanguage == AppLanguage.english
      ? 'You have no saved favorite addresses.'
      : 'Нямате запазени любими адреси.';

  static String get chooseFavoriteAddress =>
      currentLanguage == AppLanguage.english
      ? 'Choose a favorite address'
      : 'Изберете любим адрес';

  static String get languageSaveError => currentLanguage == AppLanguage.english
      ? 'Could not save the language. Please try again.'
      : 'Езикът не беше запазен. Опитайте отново.';

  static String get english {
    return 'English';
  }

  static String get bulgarian {
    return 'Български';
  }

  static String get passengerLoginTitle =>
      currentLanguage == AppLanguage.english
      ? 'Sign in to City6'
      : 'Вход в City6';

  static String get passengerPhoneTitle =>
      currentLanguage == AppLanguage.english
      ? 'Continue with your phone'
      : 'Продължете с телефона си';

  static String get passengerPhoneDescription =>
      currentLanguage == AppLanguage.english
      ? 'Enter your international phone number to receive a verification code.'
      : 'Въведете международния си телефонен номер, за да получите код за потвърждение.';

  static String get passengerPhoneLabel =>
      currentLanguage == AppLanguage.english
      ? 'Phone number'
      : 'Телефонен номер';

  static String get passengerPhoneHint => currentLanguage == AppLanguage.english
      ? '+359 88 123 4567'
      : '+359 88 123 4567';

  static String get passengerSendCode =>
      currentLanguage == AppLanguage.english ? 'SEND CODE' : 'ИЗПРАТИ КОД';

  static String get passengerPhoneInvalid =>
      currentLanguage == AppLanguage.english
      ? 'Enter a valid international number beginning with + or 00.'
      : 'Въведете валиден международен номер, започващ с + или 00.';

  static String get passengerRateLimited =>
      currentLanguage == AppLanguage.english
      ? 'Too many attempts. Please wait and try again later.'
      : 'Твърде много опити. Изчакайте и опитайте отново по-късно.';

  static String get passengerCodeTitle => currentLanguage == AppLanguage.english
      ? 'Verify your phone'
      : 'Потвърдете телефона си';

  static String get passengerCodeSentTo =>
      currentLanguage == AppLanguage.english
      ? 'We sent a verification code to'
      : 'Изпратихме код за потвърждение до';

  static String get passengerCodeLabel =>
      currentLanguage == AppLanguage.english ? '6-digit code' : '6-цифрен код';

  static String get passengerVerifyCode =>
      currentLanguage == AppLanguage.english ? 'VERIFY' : 'ПОТВЪРДИ';

  static String get passengerResendCode =>
      currentLanguage == AppLanguage.english
      ? 'Resend code'
      : 'Изпрати кода отново';

  static String passengerResendCountdown(int seconds) =>
      currentLanguage == AppLanguage.english
      ? 'You can request another message in $seconds seconds'
      : 'Можете да поискате ново съобщение след $seconds секунди';

  static String passengerCodeExpires(int seconds) {
    final minutes = seconds ~/ 60;
    final remainder = seconds % 60;
    final time = '$minutes:${remainder.toString().padLeft(2, '0')}';
    return currentLanguage == AppLanguage.english
        ? 'Code expires in $time'
        : 'Кодът изтича след $time';
  }

  static String get passengerCodeInvalid =>
      currentLanguage == AppLanguage.english
      ? 'The code is invalid or can no longer be used. Check it and try again.'
      : 'Кодът е невалиден или вече не може да се използва. Проверете го и опитайте отново.';

  static String get passengerChallengeExpired =>
      currentLanguage == AppLanguage.english
      ? 'This verification request has expired. Go back and request a new code.'
      : 'Заявката за потвърждение е изтекла. Върнете се и поискайте нов код.';

  static String get passengerResendMayRepeatCode =>
      currentLanguage == AppLanguage.english
      ? 'The message may contain the same code if it is still valid.'
      : 'Ако кодът все още е валиден, съобщението може да съдържа същия код.';

  static String get passengerChangePhone =>
      currentLanguage == AppLanguage.english
      ? 'Change number'
      : 'Промени номера';

  static String get passengerLogoutServerUnavailable =>
      currentLanguage == AppLanguage.english
      ? 'You signed out on this device, but City6 could not confirm that the remote session was revoked.'
      : 'Излязохте от този телефон, но City6 не успя да потвърди отнемането на сесията от сървъра.';

  static String get passengerSessionExpired =>
      currentLanguage == AppLanguage.english
      ? 'Your session is no longer valid. Verify your phone to continue.'
      : 'Сесията Ви вече не е валидна. Потвърдете телефона си, за да продължите.';

  static String get passengerUsername =>
      currentLanguage == AppLanguage.english ? 'Username' : 'Потребителско име';

  static String get passengerPassword =>
      currentLanguage == AppLanguage.english ? 'Password' : 'Парола';

  static String get passengerLoginButton =>
      currentLanguage == AppLanguage.english ? 'SIGN IN' : 'ВХОД';

  static String get passengerLoginInvalidCredentials =>
      currentLanguage == AppLanguage.english
      ? 'The username or password is incorrect.'
      : 'Потребителското име или паролата са грешни.';

  static String get passengerLoginNetworkError =>
      currentLanguage == AppLanguage.english
      ? 'Could not connect. Check your internet connection and try again.'
      : 'Няма връзка с интернет. Проверете връзката и опитайте отново.';

  static String get passengerLoginBackendError =>
      currentLanguage == AppLanguage.english
      ? 'City6 service is temporarily unavailable. Try again shortly.'
      : 'Услугата City6 временно не е достъпна. Опитайте отново след малко.';

  static String get passengerLoginStorageError =>
      currentLanguage == AppLanguage.english
      ? 'Secure sign-in storage is unavailable. Please try again.'
      : 'Защитеното съхранение на входа не е достъпно. Опитайте отново.';

  static String get passengerLoginUnexpectedError =>
      currentLanguage == AppLanguage.english
      ? 'Could not sign in. Please try again.'
      : 'Входът не бе успешен. Опитайте отново.';

  static String get passengerSessionCheckError =>
      currentLanguage == AppLanguage.english
      ? 'We could not verify your saved session. Your account is still saved.'
      : 'Не успяхме да проверим запазената сесия. Профилът Ви е запазен.';

  static String get retrySessionCheck => currentLanguage == AppLanguage.english
      ? 'Retry session check'
      : 'Провери отново';

  static String get logout =>
      currentLanguage == AppLanguage.english ? 'Sign out' : 'Изход';

  static String get logoutConfirmationTitle =>
      currentLanguage == AppLanguage.english
      ? 'Sign out?'
      : 'Изход от профила?';

  static String get logoutConfirmationMessage =>
      currentLanguage == AppLanguage.english
      ? 'Any active ride will remain saved for this account.'
      : 'Активната поръчка ще остане запазена за този профил.';

  static String get smsRegistrationNotAvailable =>
      currentLanguage == AppLanguage.english
      ? 'SMS registration is not available yet. Sign in with your City6 account.'
      : 'Регистрацията със SMS още не е достъпна. Влезте с Вашия City6 профил.';

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
      return 'Welcome to City6';
    }
    return 'Добре дошли в City6';
  }

  static String get pickupLocation {
    if (currentLanguage == AppLanguage.english) {
      return 'Pickup location';
    }
    return 'От къде?';
  }

  static String get myLocation => currentLanguage == AppLanguage.english
      ? 'My location'
      : 'Моето местоположение';

  static String get enterPickupAddress => currentLanguage == AppLanguage.english
      ? 'Enter pickup address'
      : 'Въведи адрес';

  static String get locationServicesDisabled =>
      currentLanguage == AppLanguage.english
      ? 'Location services are disabled.'
      : 'Услугите за местоположение са изключени.';

  static String get locationPermissionDenied =>
      currentLanguage == AppLanguage.english
      ? 'Location permission was denied.'
      : 'Достъпът до местоположението беше отказан.';

  static String get locationPermissionDeniedForever =>
      currentLanguage == AppLanguage.english
      ? 'Location permission is permanently denied. Enable it in the device settings.'
      : 'Достъпът до местоположението е забранен. Разрешете го от настройките на устройството.';

  static String get pickupCoordinatesUnavailable =>
      currentLanguage == AppLanguage.english
      ? 'Could not determine a valid pickup location. Please select it again.'
      : 'Не успяхме да определим валидна начална точка. Изберете я отново.';

  static String get destinationCoordinatesUnavailable =>
      currentLanguage == AppLanguage.english
      ? 'Could not determine a valid destination. Please select it again.'
      : 'Не успяхме да определим валидна крайна точка. Изберете я отново.';

  static String get destinationLocation {
    if (currentLanguage == AppLanguage.english) {
      return 'Destination';
    }
    return 'До къде?';
  }

  static String get chooseOnMap => currentLanguage == AppLanguage.english
      ? 'Choose on map'
      : 'Избери от картата';

  static String get mapPickerPickupTitle =>
      currentLanguage == AppLanguage.english
      ? 'Choose pickup location'
      : 'Изберете начална точка';

  static String get mapPickerDestinationTitle =>
      currentLanguage == AppLanguage.english
      ? 'Choose destination'
      : 'Изберете крайна точка';

  static String get mapPickerTapToSelect =>
      currentLanguage == AppLanguage.english
      ? 'Tap the map to choose a location'
      : 'Докоснете картата, за да изберете точка';

  static String get mapPickerSelectedAddress =>
      currentLanguage == AppLanguage.english
      ? 'Selected location'
      : 'Избрана точка';

  static String get mapPickerResolvingAddress =>
      currentLanguage == AppLanguage.english
      ? 'Finding address...'
      : 'Търсим адреса...';

  static String get confirmLocation =>
      currentLanguage == AppLanguage.english ? 'Confirm location' : 'Потвърди';

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

  static String get placeOrder {
    if (currentLanguage == AppLanguage.english) {
      return 'Order';
    }
    return 'Поръчай';
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
      return 'Your ride request has been accepted.';
    }
    return 'Поръчката Ви е приета.';
  }

  static String get rideAcceptedMessage {
    if (currentLanguage == AppLanguage.english) {
      return 'The driver is finishing the current ride and will head your way afterwards.';
    }

    return 'Шофьорът довършва текущия курс и след това ще тръгне към Вас.';
  }

  static String get acceptedRideTitle {
    if (currentLanguage == AppLanguage.english) {
      return 'Your ride request was accepted successfully';
    }
    return 'Поръчката Ви е приета успешно';
  }

  static String get acceptedRideMessage {
    if (currentLanguage == AppLanguage.english) {
      return 'The driver is on the way to you';
    }
    return 'Шофьорът пътува към Вас';
  }

  static String get rideRequestSent {
    if (currentLanguage == AppLanguage.english) {
      return 'Ride request sent';
    }

    return 'Заявката за курс е изпратена';
  }

  static String get bonusAwaitingDecision {
    if (currentLanguage == AppLanguage.english) {
      return 'No eligible driver accepted your request.';
    }
    return 'Никой от подходящите шофьори не прие заявката.';
  }

  static String get bonusOfferExplanation {
    if (currentLanguage == AppLanguage.english) {
      return 'You can offer a €5 bonus to try again. If you continue without a bonus, your request stays active and waits for an available vehicle.';
    }
    return 'Можете да предложите бонус от 5 € на шофьора, за да изпратим заявката отново. Ако продължите без бонус, заявката остава активна и ще чака свободен автомобил.';
  }

  static String get acceptFiveEuroBonus {
    if (currentLanguage == AppLanguage.english) {
      return 'Offer a €5 bonus';
    }
    return 'Предложи бонус +5 €';
  }

  static String get declineFiveEuroBonus {
    if (currentLanguage == AppLanguage.english) {
      return 'Continue without bonus';
    }
    return 'Продължи без бонус';
  }

  static String get bonusAcceptedNotice {
    if (currentLanguage == AppLanguage.english) {
      return 'Driver bonus: €5 (not included in the estimated fare).';
    }
    return 'Бонус за шофьора: 5 € (не е включен в ориентировъчната цена).';
  }

  static String get bonusDecisionFailed {
    if (currentLanguage == AppLanguage.english) {
      return 'The bonus decision could not be confirmed. Please try again.';
    }
    return 'Решението за бонуса не беше потвърдено. Моля, опитайте отново.';
  }

  static String get waitingForDriverConfirmation {
    if (currentLanguage == AppLanguage.english) {
      return 'Waiting for driver confirmation';
    }

    return 'Очаква се потвърждение от шофьора';
  }

  static String get waitingBoardWarningTitle =>
      currentLanguage == AppLanguage.english
      ? 'We’re still looking for a vehicle'
      : 'Продължаваме да търсим автомобил';

  static String get waitingBoardWarningMessage =>
      currentLanguage == AppLanguage.english
      ? 'We are currently unable to find an available vehicle for your ride. We are continuing to search for you. Thank you for your patience!'
      : 'В момента не успяваме да намерим свободен автомобил за Вашата поръчка. Продължаваме да търсим за Вас. Благодарим Ви за търпението!';

  static String get waitingBoardWarningNote =>
      currentLanguage == AppLanguage.english
      ? 'Your ride request remains active. You can cancel it at any time.'
      : 'Поръчката остава активна. Можете да я отмените по всяко време.';

  static String get driverArriving {
    if (currentLanguage == AppLanguage.english) {
      return 'Your taxi is at the pickup location';
    }

    return 'Таксито Ви е на адреса';
  }

  static String get driverArrivingMessage {
    if (currentLanguage == AppLanguage.english) {
      return 'Your driver is on the way to pick you up';
    }

    return 'Шофьорът идва';
  }

  static String get driverInfoTitle {
    if (currentLanguage == AppLanguage.english) {
      return 'Driver information';
    }

    return 'Информация за шофьора';
  }

  static String get rideInProgress {
    if (currentLanguage == AppLanguage.english) {
      return 'Ride in progress';
    }

    return 'Курсът е започнал';
  }

  static String get rideInProgressMessage {
    if (currentLanguage == AppLanguage.english) {
      return 'You are on the way to your destination.';
    }

    return 'Пътувате към вашата крайна точка.';
  }

  static String get rideCompleted {
    if (currentLanguage == AppLanguage.english) {
      return 'Ride completed';
    }

    return 'Курсът е завършен';
  }

  static String get rideCompletedMessage {
    if (currentLanguage == AppLanguage.english) {
      return 'Thank you for using City6.';
    }

    return 'Благодарим, че използвахте City6.';
  }

  static String get rideCancelled {
    if (currentLanguage == AppLanguage.english) {
      return 'Ride cancelled';
    }

    return 'Заявката е анулирана';
  }

  static String get rideCancelledMessage {
    if (currentLanguage == AppLanguage.english) {
      return 'The ride request was cancelled successfully.';
    }

    return 'Заявката за курс беше отменена успешно.';
  }

  static String get rideCancelledUnknownReasonMessage =>
      currentLanguage == AppLanguage.english
      ? 'The ride request has ended.'
      : 'Заявката за курс е приключила.';

  static String get rideNoVehicleFoundTitle =>
      currentLanguage == AppLanguage.english
      ? 'We couldn’t find a vehicle'
      : 'Не успяхме да намерим автомобил';

  static String get rideNoVehicleFoundMessage =>
      currentLanguage == AppLanguage.english
      ? 'Unfortunately, we could not find a vehicle for your ride. The request was cancelled automatically. Please try again later.'
      : 'За съжаление, не успяхме да осигурим автомобил за Вашата поръчка. Заявката е прекратена автоматично. Моля, опитайте отново по-късно.';

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
      return 'City6 - 6 seats';
    }
    return 'City6 - 6 места';
  }

  static String get luggage {
    if (currentLanguage == AppLanguage.english) {
      return 'Luggage';
    }
    return 'Багаж';
  }

  static String get luggageYes {
    if (currentLanguage == AppLanguage.english) {
      return 'With luggage';
    }

    return 'С багаж';
  }

  static String get luggageNo {
    if (currentLanguage == AppLanguage.english) {
      return 'Without luggage';
    }

    return 'Без багаж';
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

  static String get finalPriceLabel {
    if (currentLanguage == AppLanguage.english) {
      return 'Final price';
    }
    return 'Крайна цена';
  }

  static String get finalPriceUnavailable {
    if (currentLanguage == AppLanguage.english) {
      return 'Not available';
    }
    return 'Не е налична';
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

  static String get okButton {
    if (currentLanguage == AppLanguage.english) {
      return 'OK';
    }
    return 'ОК';
  }

  static String get orderTaxi {
    if (currentLanguage == AppLanguage.english) {
      return 'Book a taxi';
    }
    return 'Поръчай такси';
  }

  static String get activeRideNotice {
    if (currentLanguage == AppLanguage.english) {
      return 'You have an active ride request';
    }
    return 'Имате направена поръчка';
  }

  static String get returnToActiveRide {
    if (currentLanguage == AppLanguage.english) {
      return 'Back to ride';
    }
    return 'Обратно към поръчката';
  }

  static String get cancelActiveRide {
    if (currentLanguage == AppLanguage.english) {
      return 'Cancel ride';
    }
    return 'Отказване на поръчката';
  }

  static String get previousRideCheckFailed {
    if (currentLanguage == AppLanguage.english) {
      return 'Could not verify the previous ride request. Please try again.';
    }
    return 'Предишната заявка не можа да бъде проверена. Моля, опитайте отново.';
  }

  static String get welcomeTagline {
    if (currentLanguage == AppLanguage.english) {
      return 'Travel together';
    }

    return 'Пътувайте заедно';
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

  static String get callDriver {
    if (currentLanguage == AppLanguage.english) {
      return 'Call driver';
    }

    return 'Обади се на шофьора';
  }

  static String get callDriverFailed {
    if (currentLanguage == AppLanguage.english) {
      return 'Could not open the phone app';
    }

    return 'Телефонното приложение не можа да бъде отворено';
  }

  static String get cancelRide {
    if (currentLanguage == AppLanguage.english) {
      return 'Cancel ride';
    }

    return 'Откажи заявката';
  }

  static String get processing => currentLanguage == AppLanguage.english
      ? 'Processing...'
      : 'Обработва се...';

  static String get cancelRideConfirmationTitle {
    if (currentLanguage == AppLanguage.english) {
      return 'Cancel ride?';
    }
    return 'Отказ на заявката?';
  }

  static String get cancelRideConfirmationMessage {
    if (currentLanguage == AppLanguage.english) {
      return 'Are you sure you want to cancel this ride request?';
    }
    return 'Сигурни ли сте, че искате да отмените заявката?';
  }

  static String get cancelRideFailed {
    if (currentLanguage == AppLanguage.english) {
      return 'Could not cancel the ride request. Please try again.';
    }
    return 'Заявката не можа да бъде отменена. Моля, опитайте отново.';
  }

  static String get submitRideFailed {
    if (currentLanguage == AppLanguage.english) {
      return 'The ride request could not be sent. Please try again.';
    }

    return 'Заявката за курс не можа да бъде изпратена. Опитайте отново.';
  }

  static String get keepRide {
    if (currentLanguage == AppLanguage.english) {
      return 'Keep ride';
    }
    return 'Запази заявката';
  }
}

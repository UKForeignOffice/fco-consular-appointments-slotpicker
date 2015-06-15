angular.module('BB.Directives').directive 'SlotPicker', (LocaleService, DayService, AlertService, TimeService, FormDataStoreService) ->

  restrict: 'AEC'
  replace: true
  scope : true

  controller : ($scope,  $rootScope,  $q) ->

    $scope.settings = {
      optionLimit: 3,
      leadDays: 3,
      singleUnavailableMsg: true,
      selections: 'has-selections',
      bookableDates: [],
      allDates: [],
      originalSlots: [],
      currentSlots: [],
      calendarDayHeight: 56,
      navPointer: 0,
      scrollToFocus: true,
    }
    
    $rootScope.connection_started.then ->

      # set the data source as the current item
      $scope.data_source = $scope.bb.current_item
    
      if $scope.data_source.date
        $scope.setCurrentMonth($scope.data_source.date.date.clone())
      else 
        $scope.setCurrentMonth(moment().startOf('month'))
 

    $scope.next = () ->
      next_month = moment($scope.currentMonth.month).add(1, 'month')
      $scope.setCurrentMonth(next_month)

      
    $scope.previous = () ->
      previous_month = moment($scope.currentMonth.month).subtract(1, 'month')
      $scope.setCurrentMonth(previous_month)


    # setCurrentMonth
    # Set the month to display. Expects moment object
    $scope.setCurrentMonth = (month) ->
      id = "month-" + month.format("YYYY-MM")
      if $scope.currentMonth && $scope.currentMonth.id == id
        return
      month = month.clone()
      $scope.currentMonth = {
        name       : month.format("MMMM"),  
        id         : id
        month      : month.startOf('month')
        date_from  : moment(month).startOf('week')
        date_to    : moment(month).add(1, 'month').endOf('week')
        next_month : moment(month).add(1, 'month').format('MMMM')
        prev_month : moment(month).subtract(1, 'month').format('MMMM')
      }

      $scope.loadDays()


    $scope.isPast = () ->
      return true if moment().isSame($scope.currentMonth.month,'month')
      return false


    $scope.loadDays = () ->

     # $scope.notLoaded $scope

      if $scope.data_source

        end_date = moment($scope.currentMonth.date_to).add(1, 'days')

        DayService.query({company: $scope.bb.company, cItem: $scope.data_source, date: $scope.currentMonth.date_from.toISODate(), edate: end_date.toISODate(), client: $scope.client }).then (days) =>
          $scope.settings.bookableDates = days

          dcount    = 0
          weekblock = {week: []}

          first_week_id = $scope.weeks[0].id if $scope.weeks

          for day in $scope.settings.bookableDates

            block = {
              date: day.date.clone(), 
              day: day.date.date(), 
              today:day.date.isSame(moment(),'day'), 
              newMonth: day.date.date()==1,
              monthIso: day.date.format("YYYY-MM"),
              monthShort: day.date.format("MMM"),
              num_spaces: day.spaces
              klass: (if day.spaces > 0 then 'BookingCalendar-date--bookable' else 'BookingCalendar-date--unavailable')
            }

            # check if the date has already been selected
            if $scope.data_source.date && day.date.isSame($scope.data_source.date.date, 'day')
              block.klass = 'BookingCalendar-date--bookable'
              block.num_spaces = 1
              $scope.selectDay(block)

            # add the day to the weekblock array
            weekblock.week.push(block)
            dcount +=1
            if dcount == 7
              dcount = 0

              weekblock.id = day.date.unix()

              # add new weeks and splice existing weeks
              if !$scope.weeks?
                $scope.weeks = [weekblock]
              else
                # if the week is after the last week in the array or the week is before is before the first,
                # push it into the array. 
                if ((weekblock.id > $scope.weeks[$scope.weeks.length-1].id) or (first_week_id and weekblock.id < first_week_id)) and weekblock.id != first_week_id
                  $scope.weeks.push(weekblock)
                # if the week exists already, replace it
                else
                  index = 0
                  for week, i in $scope.weeks
                    index = i if weekblock.id is week.id                  
                  $scope.weeks.splice(index, 1, weekblock)

              weekblock = {week: []}

          # sort the weeks array
          $scope.weeks.sort (a,b) =>
            a.id - b.id

          # animate the data load
          $scope.animate()

          $scope.setLoaded $scope

        , (err) -> $scope.setLoadedAndShowError($scope, err, 'Sorry, something went wrong')
      else
        $scope.setLoaded $scope
     

    $scope.animate = () ->
      $('.BookingCalendar-mask').animate {
        scrollTop: $($("#" + $scope.currentMonth.id)[0]).closest('tr').index() * $scope.settings.calendarDayHeight
      }, 1000
      return


    $scope.selectDay = (day) =>
      $scope.selDay = {day:day, active: true, past: day.date.clone().endOf('day').isBefore(moment(), 'day')}
      $scope.loadTimes()


    $scope.loadTimes = () =>

      if $scope.data_source && $scope.data_source.days_link || $scope.item_link_source

        pslots = TimeService.query({company: $scope.bb.company, cItem: $scope.data_source, item_link: $scope.item_link_source, date: $scope.selDay.day.date, client: $scope.client, available: 1})
        
        pslots.finally =>
          $scope.setLoaded $scope
        pslots.then (data) =>

          # prevent time slots that are in the past (taking into account the companies timezone) from being shown
          local_time = moment().tz($scope.bb.company.timezone)
          local_time_mins = (local_time.hour() * 60) + local_time.minutes()

          if $scope.selDay.day.date.clone().tz($scope.bb.company.timezone).isSame(local_time, 'day')
            $scope.selDay.slots = data.filter (slot) -> slot.time >= local_time_mins
          else
            $scope.selDay.slots = data

          if $scope.data_source.time and $scope.selDay.day.date.isSame($scope.data_source.date.date)
            for t in data
              if $scope.data_source.time and t.time is $scope.data_source.time.time
                $scope.data_source.setTime(t)
                $scope.selDay.time = t.time

        , (err) ->  $scope.setLoadedAndShowError($scope, err, 'Sorry, something went wrong')

      else
        $scope.setLoaded $scope


    $scope.highlightSlot = (slot) =>
      if slot && slot.availability() > 0 && $scope.selDay.day.date
        $scope.setLastSelectedDate($scope.selDay.day.date)
        $scope.data_source.setDate({date:$scope.selDay.day.date})
        $scope.data_source.setTime(slot)


angular.module('BB.Directives').directive 'DateSlider', () ->
  restrict: 'AEC'
  replace: true
  scope : true
  #require: '^BBCtrl'



  controller : ($scope,  $rootScope,  $q, $element, $window, $timeout) ->

    $scope.slide_settings = {
      currentPos: 0,
      visibleDays: 12,
      displayDays: 5,
      selectableDays: 6,
      width: 700,
      dayWidth: 100,
      middle: 300,
      inactive: 300,
      animateSpeed: 250,
      selectonload: false,
      resizeonload: true,
      centreonday: true,
      emulatetouch: false,

      UPNESS: 0.22,
      SQUASHDAYS: 0.95,
      MAGNIFYDAY: 1.4,
      MAGNIFYFONT: 1.33,
      BORDERWIDTH: 2,
      FONTSIZESCALE: 0.52,
      SHRINKWEEKDAY: 0.42
    }

    $scope.$scrolls = $('.scroll', $element)
    $scope.$large = $('.DateSlider-largeDates', $element)
    $scope.$touch = $('.DateSlider-touch', $element)
    $scope.$months = $('.DateSlider-month span', $element)
    $scope.$buttonL = $('.DateSlider-buttonLeft', $element)
    $scope.$buttonR = $('.DateSlider-buttonRight', $element)
    $scope.$thewindow = angular.element($window)

    # needed for CSS changes
    $scope.$small = $('.DateSlider-smallDates', $element)
    $scope.$day = $('li', $element)
    $scope.$largeRow = $('.DateSlider-days', $scope.$large)

    $scope.posOfDateAt = (x) =>
      return (Math.floor(x / $scope.slide_settings.dayWidth) * $scope.slide_settings.dayWidth) - $scope.slide_settings.middle;

    $scope.posOfNearestDateTo = (x) =>
      balance = x % $scope.slide_settings.dayWidth;

      if balance > $scope.slide_settings.dayWidth / 2 
        return x - balance + $scope.slide_settings.dayWidth
      else
        return x - balance


    $scope.syncScrollPos = ($el) =>
      $el.siblings('.scroll').scrollLeft($el.scrollLeft());
    

    $scope.differentPos = (pos) =>
      if $scope.slide_settings.currentPos != pos
        $scope.slide_settings.currentPos = pos
        return true
      return false

 
    $scope.selectDateFromIndex = (index) =>
      day = $scope.$large.find('li').eq(index)
      elm  = angular.element(day).scope() 
      $scope.selectDay(elm.date)
      $scope.setCurrentMonth(elm.date.date)
    

    $scope.slide = (pos) =>
      $('.scroll', $element).animate({
        scrollLeft: pos
      }, $scope.slide_settings.animateSpeed).promise().done () =>
        $scope.$large.trigger('chosen')
      
  
    $scope.$thewindow.bind 'resize', () =>
        $scope.calculateDimensions();
        $scope.resizeElements();
        $scope.centreDateWhenInactive(self);

    $scope.calculateDimensions = () =>
      set = $scope.slide_settings
      set.viewPort        = $element.width()
      
      set.visibleDays     = $scope.$small.find('li').length;
      set.selectableDays  = $scope.$large.find('li').length;

      set.dayWidth        = Math.floor(set.viewPort / set.displayDays);
      set.width           = set.dayWidth * set.displayDays;
      set.middle          = Math.floor(set.displayDays / 2) * set.dayWidth;
      
      set.dayHeight       = Math.floor(set.dayWidth * set.SQUASHDAYS);
      set.largeHeight     = Math.floor(set.dayHeight * set.MAGNIFYDAY);
      set.largeLineHeight = (set.largeHeight * set.UPNESS) * 2 + set.dayHeight;
      set.topOffset       = Math.floor(set.largeHeight * set.UPNESS);
      
      set.fontSmall       = set.dayHeight * set.FONTSIZESCALE;
      set.fontLarge       = set.fontSmall * set.MAGNIFYFONT;
      set.fontSmaller     = set.fontLarge * set.SHRINKWEEKDAY;


    $scope.resizeElements = () =>
      unit = 'px'
      set = $scope.slide_settings
      el = $element

      if !set.resizeonload
        return el.css({visibility: 'visible'})
      
      
      $scope.$buttonL.add($scope.$buttonR).css({
        width: set.dayWidth + unit,
        height: set.dayHeight + unit,
        fontSize: set.fontLarge + unit,
        lineHeight: set.dayHeight + unit
      })
      
      $('.DateSlider-sliders', el).css({
        height: set.dayHeight + unit
      })
      
      $scope.$day = $('li', $element)
      
      $scope.$day.css({
        width: set.dayWidth + unit,
        fontSize: set.fontSmall + unit,
        lineHeight: set.dayHeight + unit
      })
      
      $('.DateSlider-days', $scope.$touch).css({
        width: (set.dayWidth * set.visibleDays) + unit
      })
      
      $('.DateSlider-days', $scope.$small).css({
        width: (set.dayWidth * set.visibleDays) + unit
      })
      
      $scope.$largeRow.css({
        width: (set.dayWidth * set.selectableDays) + unit
      })
      
      $('li', $scope.$largeRow).css({
        fontSize: set.fontLarge + unit,
        lineHeight: set.largeLineHeight + unit
      })

      $('small', $scope.$largeRow).css({
        fontSize: set.fontSmaller + unit
      })

      $scope.$scrolls.css({
        width: set.viewPort + unit
      })

      $scope.$touch.css({
        height: set.largeHeight + set.BORDERWIDTH * 2 + unit,
        top: -Math.floor(set.largeHeight * set.UPNESS) + unit
      })

      $scope.$large.css({
        height: set.largeHeight + unit,
        width: set.dayWidth + unit,
        top: -(set.topOffset - set.BORDERWIDTH) + unit,
        left: set.middle + unit
      })

      $('.DateSlider-portalFrame', el).css({
        width: (set.dayWidth - set.BORDERWIDTH) + unit,
        height: set.largeHeight + unit,
        top: -set.topOffset + unit,
        left: (set.middle - set.BORDERWIDTH / 2) + unit
      })

      el.css({
        visibility: 'visible'
      })

    $scope.$watch 'settings.bookableDates', (newval, oldval) =>
      if $scope.settings.bookableDates and $scope.settings.bookableDates.length > 0 and Modernizr.touch


        # push only from the first available date onwards
        slider_dates = []
        for d in $scope.settings.bookableDates
          if d.spaces > 0 or first_available_day_found 
            first_available_day_found = true
            slider_dates.push(d)


        dates = slider_dates
        if !$scope.settings.cached_dates 
          $scope.settings.cached_dates = slider_dates
        else
          dhash  = {}
          for d in $scope.settings.cached_dates 
            dhash[d.string_date] = d
          for d in slider_dates

            if !dhash[d.string_date]
              $scope.settings.cached_dates.push(d)
              dhash[d.string_date] = d
          $scope.settings.cached_dates.sort (a,b)->
            a.date.unix() - b.date.unix() 
          dates = $scope.settings.cached_dates

        buf = []
        first = dates[0]
        last = dates[dates.length - 1]
        buffer = Math.floor($scope.slide_settings.displayDays / 2)
        for i in [buffer..1] by -1
          buf.push({date: first.date.clone().add(-i, 'days'), spaces:0})
        buf = buf.concat(dates)
        for i in [1..buffer] by 1
          buf.push({date: first.date.clone().add(i, 'days'), spaces:0})

        $scope.slide_settings.buffer_dates = buf  
        $scope.slide_settings.all_dates = dates

        $scope.selectDay(slider_dates[0]) if !$scope.selDay

        $timeout () =>
          $scope.calculateDimensions();
          $scope.resizeElements();
        , 1

    $scope.centreDateWhenInactive = (obj) =>

      if !$scope.slide_settings.centreonday
        return

      clearTimeout(obj.scrollTimer)

      obj.scrollTimer = setTimeout () =>
        $scope.slide($scope.posOfNearestDateTo($scope.$large.scrollLeft()))
      , $scope.slide_settings.inactive




angular.module('BB.Directives').directive 'DateSliderTouch', () ->
  restrict: 'AEC'
  replace: true
  scope : true
  #require: '^BBCtrl'


  link: (scope, element, attrs) ->
    # initialise moment locale
    element.on {
        scroll: () =>
          scope.syncScrollPos(element);
        ,
        click: (e) =>
          scope.slide(scope.posOfDateAt(e.offsetX));
      }

  controller : ($scope,  $rootScope,  $q) ->


angular.module('BB.Directives').directive 'DateSliderLargeDates', () ->
  restrict: 'AEC'
  replace: true
  scope : true
  #require: '^BBCtrl'


  link: (scope, element, attrs) ->
    # initialise moment locale
    #moment.locale(LocaleService)
    element.on {
        chosen: () =>
          if scope.differentPos(element.scrollLeft())
            scope.selectDateFromIndex(scope.slide_settings.currentPos / scope.slide_settings.dayWidth)
        ,
        scroll: () =>
          scope.centreDateWhenInactive(scope);
      }

  controller : ($scope,  $rootScope,  $q, $element) ->


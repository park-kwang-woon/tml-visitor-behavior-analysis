# Load libraries ----
library(readxl)
library(lubridate)
library(dplyr)
library(zoo)
library(corrplot)
library(ggplot2)
library(tidyr)
library(modeest)


# Set env and load data ----
rm(list=ls())

Sys.setlocale(category = "LC_ALL", locale = "Bulgarian")

data_sheet1=readxl::read_excel("TML_vistors_case_study_data.xlsx",sheet=1)
data_sheet2=readxl::read_excel("TML_vistors_case_study_data.xlsx",sheet=2)
data_sheet3=readxl::read_excel("TML_vistors_case_study_data.xlsx",sheet=3)

df_sheet1=as.data.frame(data_sheet1)
df_sheet2=as.data.frame(data_sheet2)
df_sheet3=as.data.frame(data_sheet3)

### TABLE 1 PREPROCESSING ---

## TECHNICAL ANALYSIS 

sapply(df_sheet1,class)
summary(df_sheet1)

# Transform the columns in the correct data type
df_sheet1$Роля <- as.factor(df_sheet1$Роля)
df_sheet1$Дата <- ymd(df_sheet1$Дата)
df_sheet1$`Дата на влизане` <- ymd_hms(df_sheet1$`Дата на влизане`, tz = "UTC")
df_sheet1$`Дата на излизане`<- ymd_hms(df_sheet1$`Дата на излизане`, tz = "UTC")

sapply(df_sheet1,class)
summary(df_sheet1)

## END TECHNICAL ANALYSIS 

## DATA CONSISTENSY

# Remove duplicates by combination of USERNAME and `Дата на влизане`. 
# If the same user tried to enter the park more than once at the exact same time, 
# this is considered data error.
df_sheet1 = df_sheet1 %>%
  distinct(USERNAME, `Дата на влизане`, .keep_all = TRUE)

nrow(df_sheet1)

# Filter out any role other than visitor, adult, or child
roles_of_interest <- c('Visitor', 'Възрастен', 'Дете')

df_sheet1 = df_sheet1 %>%
  filter(df_sheet1$Роля %in% roles_of_interest)

nrow(df_sheet1)

# Populate any missing current points and total points with 0s

s1=data.frame(nm=names(df_sheet1),nas=colSums(is.na(df_sheet1)))

df_sheet1$duration = ifelse(
  !is.na(df_sheet1$`Дата на излизане`), 
  df_sheet1$`Дата на излизане` - df_sheet1$`Дата на влизане`, 
  NA) 


nrow(df_sheet1[df_sheet1$duration > 14400,])

df_sheet1$`Точки за посещението`= ifelse(is.na(df_sheet1$`Точки за посещението`),
                                         0,
                                         df_sheet1$`Точки за посещението`)
   
# Compute the total points of the user by summing the points of each visits.
# If the value in `Общи точки на посетителя` column is less than the new computed 
# value for total points then override the value in `Общи точки на посетителя`.
total_points_per_user = df_sheet1 %>%
  group_by(USERNAME) %>%
  filter(!is.na(`Точки за посещението`)) %>%
  summarize(total.points=sum(`Точки за посещението`))

df_sheet1 = df_sheet1 %>% left_join(total_points_per_user, by=c("USERNAME"))

df_sheet1$`Общи точки на посетителя` = ifelse(df_sheet1$`Общи точки на посетителя` < df_sheet1$total.points,
                                              df_sheet1$total.points,
                                              df_sheet1$`Общи точки на посетителя`)
df_sheet1 %>%
  filter(df_sheet1$`Общи точки на посетителя` < df_sheet1$`Точки за посещението`)

summary(df_sheet1)

# Fix any record with duration over 4 hours to have exactly 4 hours duration
df_sheet1$`Дата на излизане` = ymd_hms(ifelse(df_sheet1$duration > 14400,
                                              format(as.POSIXct(df_sheet1$`Дата на влизане` + hours(4), origin = "1970-01-01"), "%Y-%m-%d %H:%M:%S"),
                                              format(as.POSIXct(df_sheet1$`Дата на излизане`, origin = "1970-01-01"), "%Y-%m-%d %H:%M:%S")))

df_sheet1$duration = ifelse(!is.na(df_sheet1$`Дата на излизане`), df_sheet1$`Дата на излизане` - df_sheet1$`Дата на влизане`, NA) 
mean_duration = mean(df_sheet1$duration[!is.na(df_sheet1$duration)])

# Any missing exit time record should be fixed to enter time + mean duration;
df_sheet1$`Дата на излизане` = ymd_hms(ifelse(is.na(df_sheet1$`Дата на излизане`),
                                              format(as.POSIXct(df_sheet1$`Дата на влизане` + mean_duration, origin = "1970-01-01"), "%Y-%m-%d %H:%M:%S"),
                                              format(as.POSIXct(df_sheet1$`Дата на излизане`, origin = "1970-01-01"), "%Y-%m-%d %H:%M:%S")))

summary(df_sheet1)

boxplot(df_sheet1$duration)
summary(df_sheet1$duration)


boxplot(df_sheet1$`Общи точки на посетителя`)
summary(df_sheet1$`Общи точки на посетителя`)


## END DATA CONSISTENSY
### END TABLE 1 PREPROCESSING

# ---------------------------------------------

### TABLE 2 PREPROCESSING
sapply(df_sheet2,class)
summary(df_sheet2)

## TECHNICAL ANALYSIS 

# First we convert the columns with data inside to date
df_sheet2 <- df_sheet2 %>%
  mutate(
    Дата = as.Date(Дата, format = "%Y-%m-%d"),
    `Начало на игра` = ymd_hms(`Начало на игра`),
    `Край на игра` = ymd_hms(`Край на игра`)
  )

#Factorization of columns Роля and Експонат
df_sheet2 <- df_sheet2 %>%
  mutate(
    Роля = factor(Роля),
    Експонат = factor(Експонат)
  ) %>%
  distinct() # Remove duplicate values

## END TECHNICAL ANALYSIS 

## DATA CONSISTENSY

# Check `Продължителност минути` what type of data it is
class(df_sheet2$`Продължителност минути`)
# it is numeric so we don't need to adjust its formatting

df_sheet2 <- df_sheet2 %>%
  filter(Дата != "2018-06-23") %>% # Remove data from the opening day as per instruction from Boryana Pelova
  filter(Роля %in% c("Visitor", "Дете", "Възрастен"))  %>% # Remove roles we are not interested in evaluating
  filter(`Продължителност минути` < 240.01) # Remove values greater than 4 hours
  

# get summary for time spent on experiments
summary_df_sheet2 <- df_sheet2 %>%
  select(Експонат, `Продължителност минути`) %>%
  group_by(Експонат) %>%
  summarize(
    Mean_Value = mean(`Продължителност минути`, na.rm = TRUE),
    Count = n()
  )

#Replace missing values with averages from summary_df_sheet2
df_sheet2 <- df_sheet2 %>%
  mutate(
    `Продължителност минути` = ifelse(
      is.na(`Продължителност минути`),  # Check if value is NA
      summary_df_sheet2$Mean_Value[match(Експонат, summary_df_sheet2$Експонат)],  # Replace with mean value from summary_df_sheet2
      `Продължителност минути`  # Keep original value if it's not NA
    ))

#Filling out N/A in `Край на игра` by summing `Начало на игра` and Продължителност
df_sheet2 <- df_sheet2 %>%
  mutate(
    Продължителност.секунди = `Продължителност минути` * 60,  # Convert minutes to seconds
    `Край на игра` = ifelse(
      is.na(`Край на игра`), 
      as.character(`Начало на игра` + seconds(Продължителност.секунди)),  # Add duration to start time
      as.character(`Край на игра`)  # Keep original value if not NA
    )
  ) %>%
  mutate(
    `Край на игра` = ymd_hms(`Край на игра`)  # Convert back to time
  )

summary(df_sheet2)
zeros=sum(df_sheet2$`Продължителност минути`==0)
print(zeros)
edinici=sum(df_sheet2$`Продължителност минути`<=0.5)
print(edinici)
## END DATA CONSISTENSY

### END TABLE 2 PREPROCESSING

# ---------------------------------------------

### TABLE 3 PREPROCESSING

# Проверка класовете и броя на липсващите записи във всяка колона
nrow(df_sheet3)
sapply(df_sheet3, class)
aux = data.frame(nm = names(df_sheet3), nas = colSums(is.na(df_sheet3)))

## TECHNICAL ANALYSIS 

# Трансформиране колоните в правилния тип данни
df_sheet3$`Гривна ниво` <- as.factor(df_sheet3$`Гривна ниво`)

## END TECHNICAL ANALYSIS 

## DATA CONSISTENSY

# Изтриване на дублиращите "USERNAME". 

df_sheet3 = df_sheet3 %>%
  distinct(USERNAME, `Поредна гривна`, .keep_all = TRUE)

nrow(df_sheet3)

# Премахване на редовете, където стойността в колона "Брой визити общо" е 0
df_sheet3 = df_sheet3[df_sheet3$`Брой визити общо` != 0, ]

# Проверка и попълване на липсващи стойности в "Гривна ниво"
df_sheet3$`Гривна ниво` <- ifelse(
  is.na(df_sheet3$`Гривна ниво`), 
  ifelse(df_sheet3$`Общи точки на посетителя в момента` <= 199, "Начинаещ",
         ifelse(df_sheet3$`Общи точки на посетителя в момента` <= 399, "Откривател", 
                ifelse(df_sheet3$`Общи точки на посетителя в момента` <= 599, "Търсач", "Магьосник"))),
  ifelse(df_sheet3$`Общи точки на посетителя в момента` <= 199, "Начинаещ",
         ifelse(df_sheet3$`Общи точки на посетителя в момента` <= 399, "Откривател", 
                ifelse(df_sheet3$`Общи точки на посетителя в момента` <= 599, "Търсач", "Магьосник")))
)

# Преглед на резултатите след корекцията
summary(df_sheet3)

## END DATA CONSISTENSY

summary(df_sheet1)
summary(df_sheet2)
summary(df_sheet3)

count_zeros <- sum(df_sheet2$`Продължителност минути` == 0)
print(count_zeros)
### PRELIMINARY ANALYSIS ###

data2_preliminary = df_sheet2 %>%
  filter(Роля %in% c("Дете", "Възрастен", "Visitor")) %>%  # Филтриране на хората с определени роли
  group_by(USERNAME) %>%  # Групиране по потребител
  mutate(
    number_of_visits = n_distinct(Дата),  # Изчисляване на уникалните дати
    total_points = sum(`Получени точки`, na.rm = TRUE)  # Изчисляване на общите точки
  ) %>%
  filter(number_of_visits > 1) %>%  # Филтър за потребители с повече от едно посещение
  ungroup() %>%  # Премахване на групирането
  arrange(desc(number_of_visits))  # Подреждане по брой уникални дати

hist(data2_preliminary$`Получени точки`)
hist(data2_preliminary$`Продължителност минути`)


# Средни точки
df_mean_points = data2_preliminary %>%
  group_by(USERNAME) %>%
  summarise(
    total_points = sum(`Получени точки`, na.rm = TRUE),      # Сума на общите точки
    number_of_visits = n_distinct(Дата),              # Уникални посещения
    mean_points = total_points / number_of_visits,     # Средни точки на посещение
    .groups = "drop"                                # Премахване на групирането
  ) %>%
  arrange(desc(mean_points))  # Подреждане по средни точки

hist(df_mean_points$mean_points)

# Средно време на работа с експонатите

df_experiments = data2_preliminary %>%
  group_by(Експонат) %>%
  mutate(
    mean.time.per.experiment = mean(`Продължителност минути`, na.rm = TRUE),  # Средно време за експоната
    std_deviation = sd(`Продължителност минути`, na.rm = TRUE)                 # Стандартно отклонение
  ) %>%
  filter(
    `Продължителност минути` >= mean.time.per.experiment - 0.08 * std_deviation &     # Филтриране на аутлайъри
    `Продължителност минути` <= mean.time.per.experiment + 0.2 * std_deviation
  ) %>%



  group_by(Експонат) %>%
  summarise(
    total.duration = sum(`Продължителност минути`, na.rm = TRUE),              # Общо време без аутлайъри
    total.interactions = n(),                                          # Брой взаимодействия
    total.points = sum(`Получени точки`, na.rm = TRUE),                     # Общо получени точки
    mean.interaction.duration = total.duration / total.interactions,                    # Средно време на взаимодействие
    .groups = "drop"
  ) %>%
  arrange(desc(mean.interaction.duration))  # Подреждане по средно време

# Създаваме графика 1
ggplot(df_experiments, aes(x = reorder(Експонат, mean.interaction.duration), y = mean.interaction.duration)) +
  geom_bar(stat = "identity", fill = "blue") +  # Създава стълбовете със средно време
  coord_flip() +                               # Обръща оста, за да са експонатите един под друг
  labs(
    title = "Средно време на взаимодействие по експонати",
    x = "Експонат",
    y = "Средно време (минути)"
  ) +
  theme_minimal() +                            # Приложение на минимален стил
  theme(
    axis.text.y = element_text(size = 10),     # Регулиране на текста за оста Y
    axis.text.x = element_text(size = 10)      # Регулиране на текста за оста X
  )

# Създаваме графика по посещаемост на експонатите
ggplot(df_experiments, aes(x = reorder(Експонат, total.duration), y = total.duration)) +
  geom_bar(stat = "identity", fill = "blue") +  # Създава стълбовете със средно време
  coord_flip() +                               # Обръща оста, за да са експонатите един под друг
  labs(
    title = "Общо време прекарано на експонат",
    x = "Експонат",
    y = "Общо Време"
  ) +
  theme_minimal() +                            # Приложение на минимален стил
  theme(
    axis.text.y = element_text(size = 10),     # Регулиране на текста за оста Y
    axis.text.x = element_text(size = 10)      # Регулиране на текста за оста X
  )
hist(df_sheet2$"Продължителност минути")
# Създаваме графика на брой взаимодействия с експонат
ggplot(df_experiments, aes(x = reorder(Експонат, total.interactions), y = total.interactions)) +
  geom_bar(stat = "identity", fill = "blue") +  # Създава стълбовете със средно време
  coord_flip() +                               # Обръща оста, за да са експонатите един под друг
  labs(
    title = "Общ брой взимодействия с експонат",
    x = "Експонат",
    y = "Брой взаимодействия"
  ) +
  theme_minimal() +                            # Приложение на минимален стил
  theme(
    axis.text.y = element_text(size = 10),     # Регулиране на текста за оста Y
    axis.text.x = element_text(size = 10)      # Регулиране на текста за оста X
  )

# Създаваме топ 10 потребители

top_10_общо_точки = df_mean_points %>%
  arrange(desc(total_points)) %>%
  slice_head(n = 10)  # Избира първите 10 потребители

top_10_средни_точки = df_mean_points %>%
  arrange(desc(mean_points)) %>%
  slice_head(n = 10)  # Избира първите 10 потребители

top_10_брой_посещения = df_mean_points %>%
  arrange(desc(number_of_visits)) %>%
  slice_head(n = 10)  # Избира първите 10 потребители

# Графики:
ggplot(top_10_общо_точки, aes(x = reorder(USERNAME, total_points), y = total_points)) +
  geom_bar(stat = "identity", fill = "blue") +
  coord_flip() +
  labs(
    title = "Топ 10 потребители по общо точки",
    x = "Потребител",
    y = "Общо точки"
  ) +
  theme_minimal()

ggplot(top_10_брой_посещения, aes(x = reorder(USERNAME, number_of_visits), y = number_of_visits)) +
  geom_bar(stat = "identity", fill = "green") +
  coord_flip() +
  labs(
    title = "Топ 10 потребители по брой посещения",
    x = "Потребител",
    y = "Брой посещения"
  ) +
  theme_minimal()


ggplot(top_10_средни_точки, aes(x = reorder(USERNAME, mean_points), y = mean_points)) +
  geom_bar(stat = "identity", fill = "orange") +
  coord_flip() +
  labs(
    title = "Топ 10 потребители по средни точки",
    x = "Потребител",
    y = "Средни точки"
  ) +
  theme_minimal()

# Измерваме трудността на точките

Trudnost = df_experiments %>%
  group_by(Експонат) %>%         # Групиране по експонат
  summarise(
    коефициент_трудност = total.duration / total.points,           # Изчисляване на трудността
    .groups = "drop"                                         # Премахване на групирането
  ) %>%
  arrange(desc(коефициент_трудност))  # Подреждане по трудност
# Графика на трудността
ggplot(Trudnost, aes(x = reorder(Експонат, коефициент_трудност), y = коефициент_трудност)) +
  geom_bar(stat = "identity", fill = "green") +
  coord_flip() +
  labs(
    title = "Коефициент на трудност",
    x = "Експонат",
    y = "Трудност"
  ) +
  theme_minimal()
# Анализ на конкретни потребители

eksponatikarim = data2_preliminary %>%
  filter(USERNAME=="karimkhazal")%>%
  group_by(Експонат) %>%
  mutate(
    средно_време_експонат = mean(`Продължителност минути`, na.rm = TRUE),  # Средно време за експоната
    std_откл = sd(`Продължителност минути`, na.rm = TRUE)                 # Стандартно отклонение
  ) %>%
  group_by(Експонат) %>%
  summarise(
    общо_време = sum(`Продължителност минути`, na.rm = TRUE),              # Общо време без аутлайъри
    общо_взаимодействие = n(),                                          # Брой взаимодействия
    общо_точки = sum(`Получени точки`, na.rm = TRUE),                     # Общо получени точки
    средно_време = общо_време / общо_взаимодействие,                    # Средно време на взаимодействие
    .groups = "drop"
  ) %>%
  arrange(desc(общо_време))  # Подреждане по средно време
top_10_karim = eksponatikarim %>%
  arrange(desc(общо_време)) %>%
  slice_head(n = 10)  # Избира първите 10 потребители

# Разглеждане на втори потребител 
eksponatiDDM = data2_preliminary %>%
  filter(USERNAME=="DDM12345")%>%
  group_by(Експонат) %>%
  mutate(
    средно_време_експонат = mean(`Продължителност минути`, na.rm = TRUE),  # Средно време за експоната
    std_откл = sd(`Продължителност минути`, na.rm = TRUE)                 # Стандартно отклонение
  ) %>%
  group_by(Експонат) %>%
  summarise(
    общо_време = sum(`Продължителност минути`, na.rm = TRUE),              # Общо време без аутлайъри
    общо_взаимодействие = n(),                                          # Брой взаимодействия
    общо_точки = sum(`Получени точки`, na.rm = TRUE),                     # Общо получени точки
    средно_време = общо_време / общо_взаимодействие,                    # Средно време на взаимодействие
    .groups = "drop"
  ) %>%
  arrange(desc(общо_време))  # Подреждане по средно време

top_10_DDM = eksponatiDDM %>%
  arrange(desc(общо_време)) %>%
  slice_head(n = 10)  # Избира първите 10 потребители

### END PRELIMINARY ANALYSIS ###

### ANALYSIS OF CUSTOMERS BEHAVIOUR ###

## Users visited only 1 ##

# Preparation of data frame for further analysis for visitors visited 1
df_stat_user_1 <- df_sheet1 %>%
  select(USERNAME, duration, `Точки за посещението`) %>% 
  group_by(USERNAME) %>%
  summarise(
    n = n(),  # Count number of rows (visits)
    total_points = sum(`Точки за посещението`, na.rm = TRUE),  # Sum of points
    visit_durations = list(duration)  # Store all durations in a list
  ) %>%
  filter(n==1)  %>%
  #  filter(total_points>0) %>%
  unnest(visit_durations) %>% # Ensure `visit_durations` is flattened (unnest it)
  mutate(
    visit_durations = as.numeric(as.character(visit_durations)))


# Extracting mode, median and mean
stats_user_1 <- df_stat_user_1 %>%
  summarise(
    mean = mean(total_points, na.rm = TRUE),
    median = median(total_points, na.rm = TRUE),
    mode = mlv(total_points, method = "mfv", na.rm = TRUE))

stats_user_1_duration <- df_stat_user_1 %>%
  summarise(
    mean = mean(visit_durations, na.rm = TRUE),
    median = median(visit_durations, na.rm = TRUE),
    mode = mlv(visit_durations, method = "mfv", na.rm = TRUE))


# Plot the distributions for points earned for visitors with 1 visit
ggplot(df_stat_user_1, aes(x = total_points)) +
  geom_histogram(aes(y = ..density..), bins = 30, alpha = 0.6, position = "identity") +
  geom_density(alpha = 0.3) +
  geom_vline(data = stats_user_1, aes(xintercept = mean, color = "Mean"), linetype = "dashed", size = 1) +
  geom_vline(data = stats_user_1, aes(xintercept = median, color = "Median"), linetype = "solid", size = 1) +
  geom_vline(data = stats_user_1, aes(xintercept = mode, color = "Mode"), linetype = "dotted", size = 1) +
  labs(
    title = "Distribution of Total Points for users visited only 1",
    x = "Total Points",
    y = "Density",
    color = "Statistics"
  ) +
  xlim(0, 100) + # Showing up to max 100 points because the distribution is highly squed (more clarity)
  theme_minimal() +
  scale_color_manual(values = c("Mean" = "red", 
                                "Median" = "darkred",
                                "Mode" = "pink"))

ggplot(df_stat_user_1, aes(x = total_points)) +
  geom_histogram(aes(y = ..density..), bins = 30, alpha = 0.6, position = "identity") +
  geom_density(alpha = 0.3) +
  geom_vline(data = stats_user_1, aes(xintercept = mean, color = "Mean"), linetype = "dashed", size = 1) +
  geom_vline(data = stats_user_1, aes(xintercept = median, color = "Median"), linetype = "solid", size = 1) +
  geom_vline(data = stats_user_1, aes(xintercept = mode, color = "Mode"), linetype = "dotted", size = 1) +
  labs(
    title = "Distribution of Total Points for users visited only 1 and earned more than 100 points",
    x = "Total Points",
    y = "Density",
    color = "Statistics"
  ) +
  xlim(100, 500) + # Showing up to max 100 points because the distribution is highly squed (more clarity)
  theme_minimal() +
  scale_color_manual(values = c("Mean" = "red", 
                                "Median" = "darkred",
                                "Mode" = "pink"))

# Plot the distributions for time spent for visitors with 1 visit
ggplot(df_stat_user_1, aes(x = visit_durations)) +
  geom_histogram(aes(y = ..density..), bins = 30, alpha = 0.6, position = "identity") +
  geom_density(alpha = 0.3) +
  geom_vline(data = stats_user_1_duration, aes(xintercept = mean, color = "Mean"), linetype = "dashed", size = 1) +
  geom_vline(data = stats_user_1_duration, aes(xintercept = median, color = "Median"), linetype = "solid", size = 1) +
  geom_vline(data = stats_user_1_duration, aes(xintercept = mode, color = "Mode"), linetype = "dotted", size = 1) +
  labs(
    title = "Distribution of time spent for users visited only 1 and spent 500 mins inside",
    x = "Time spent",
    y = "Density",
    color = "Statistics"
  ) +
  theme_minimal() +
  scale_color_manual(values = c("Mean" = "red", 
                                "Median" = "darkred",
                                "Mode" = "pink"))
##

##Users visited more than 1 ##
# We want to examine their first visit to determine what made users come second time

# Identify first visits for users with more than one visit
first_visits <- df_sheet1 %>%
  group_by(USERNAME) %>%
  filter(n() > 1) %>%
  arrange(Дата) %>%
  slice(1)

# Extracting mode, median and mean
stats_user_not_1 <- first_visits %>%
  ungroup() %>%
  summarise(
    mean = mean(total.points, na.rm = TRUE),
    median = median(total.points, na.rm = TRUE),
    mode = mlv(total.points, method = "mfv", na.rm = TRUE))

stats_user_1_not_duration <- first_visits %>%
  ungroup() %>%
  summarise(
    mean = mean(duration, na.rm = TRUE),
    median = median(duration, na.rm = TRUE),
    mode = mlv(duration, method = "mfv", na.rm = TRUE))

# Plot the distributions for points earned for visitors with more than 1 visit
ggplot(first_visits, aes(x = total.points)) +
  geom_histogram(aes(y = ..density..), bins = 30, alpha = 0.6, position = "identity") +
  geom_density(alpha = 0.3) +
  geom_vline(data = stats_user_not_1, aes(xintercept = mean, color = "Mean"), linetype = "dashed", size = 1) +
  geom_vline(data = stats_user_not_1, aes(xintercept = median, color = "Median"), linetype = "solid", size = 1) +
  geom_vline(data = stats_user_not_1, aes(xintercept = mode, color = "Mode"), linetype = "dotted", size = 1) +
  labs(
    title = "Distribution of Total Points for users visited more than 1",
    x = "Total Points",
    y = "Density",
    color = "Statistics"
  ) +
  theme_minimal() +
  scale_color_manual(values = c("Mean" = "red", 
                                "Median" = "darkred",
                                "Mode" = "pink"))

# Plot the distributions for time spent for visitors with more than 1 visit
ggplot(first_visits, aes(x = duration)) +
  geom_histogram(aes(y = ..density..), bins = 30, alpha = 0.6, position = "identity") +
  geom_density(alpha = 0.3) +
  geom_vline(data = stats_user_1_not_duration, aes(xintercept = mean, color = "Mean"), linetype = "dashed", size = 1) +
  geom_vline(data = stats_user_1_not_duration, aes(xintercept = median, color = "Median"), linetype = "solid", size = 1) +
  geom_vline(data = stats_user_1_not_duration, aes(xintercept = mode, color = "Mode"), linetype = "dotted", size = 1) +
  labs(
    title = "Distribution of time spent for users visited more than 1",
    x = "Time spent",
    y = "Density",
    color = "Statistics"
  ) +
  theme_minimal() +
  scale_color_manual(values = c("Mean" = "red", 
                                "Median" = "darkred",
                                "Mode" = "pink"))

### END ANALYSIS OF CUSTOMERS BEHAVIOUR ###

### START CORRELATION MATRIX OF EXPERIMENTS AGGREGATED BY DAY VISIT ###

# Create table for correlation
corr_days = df_sheet2 %>%
  select(Дата, Експонат, `Продължителност минути`)

corr_days = corr_days %>%
  group_by(Дата, Експонат) %>%
  summarise(Посещения = n(), .groups = "drop")

corr_days = corr_days %>%
  pivot_wider(names_from = Експонат, 
              values_from = Посещения, 
              values_fill = 0)
# Fill NaN with 0

cor_matrix <- cor(corr_days %>% select(-Дата))

summary(cor_matrix)

# Convert correlation matrix to long format for plotting
cor_long <- as.data.frame(as.table(cor_matrix))

# Plot the heatmap
ggplot(cor_long, aes(Var1, Var2, fill = Freq)) +
  geom_tile() +
  scale_fill_gradient2(low = "blue", mid = "white", high = "red", midpoint = 0, 
                       limits = c(-1, 1), name = "Correlation") +
  labs(
    title = "Correlation Between Experiments",
    x = "Experiment",
    y = "Experiment"
  ) +
  theme_minimal() +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1)
  )

### END CORRELATION MATRIX OF EXPERIMENTS AGGREGATED BY DAY VISIT ###


### START CORRELATION MATRIX OF AGGREGATED COLUMNS ###

### Creating a correlation matrix by total number of visits X mean points per visit X total points 
### X mean time per experiment X number of visited experiments;

df_total_number_visits = df_sheet1 %>% 
  group_by(USERNAME) %>%
  summarise(total.number.of.visits=n(), 
            mean.points.per.visit=mean(`Точки за посещението`),
            total.points=max(`Общи точки на посетителя`)
  )

df_sheet2_above_zero_points = df_sheet2 %>%
  filter(`Получени точки` > 0)

df_mean_number_visited_experiments = df_sheet2_above_zero_points %>%
  group_by(USERNAME, `Дата`) %>%
  summarise(number.of.visited.experiment=n()) %>%
  group_by(USERNAME) %>%
  summarise(mean.number.of.visited.experiment=mean(number.of.visited.experiment))

df_mean_duration = df_sheet2_above_zero_points %>%
  group_by(USERNAME) %>%
  summarise(mean.time.per.experiment=mean(`Продължителност минути`),
            mean.points.per.experiment=mean(`Получени точки`)
  )

common_col_names <- intersect(names(df_total_number_visits), names(df_mean_duration))
df_aggregated_by_user = merge(df_total_number_visits, df_mean_duration, by=common_col_names, all.x=TRUE)
common_col_names <- intersect(names(df_aggregated_by_user), names(df_mean_number_visited_experiments))
df_aggregated_by_user = merge(df_aggregated_by_user, df_mean_number_visited_experiments, by=common_col_names, all.x=TRUE)

df_aggregated_by_user = na.omit(df_aggregated_by_user)

summary(df_aggregated_by_user)

cor_matrix <- cor(df_aggregated_by_user[,-1])
colnames(cor_matrix) <- c("Брой посещения", "Среден брой точки на посещение",
                          "Общ брой точки", "Среден престой на експонат",
                          "Среден брой точки от експонат", "Среден брой посетени експонати")
rownames(cor_matrix) <- c("Брой посещения", "Среден брой точки на посещение",
                          "Общ брой точки", "Среден престой на експонат",
                          "Среден брой точки от експонат", "Среден брой посетени експонати")
print(cor_matrix)

corrplot(cor_matrix, method="number", col = colorRampPalette(c("red", "lightgray", "blue"))(200))

### END CORRELATION MATRIX


### START CLUSTER ANALYSIS

library(cluster)
library(factoextra)

## Cluster analysis of total.number.of.visits and mean.points.per.visit

df_num_visits_x_mean_points_visit = df_aggregated_by_user[,c("total.number.of.visits", "mean.points.per.visit")]
df_num_visits_x_mean_points_visit_scaled = scale(df_num_visits_x_mean_points_visit)

fviz_nbclust(df_num_visits_x_mean_points_visit_scaled, kmeans, method = "wss")

km=kmeans(df_num_visits_x_mean_points_visit_scaled, centers = 5, nstart = 10, iter.max = 100)

grDevices::windows()
plot(df_num_visits_x_mean_points_visit$total.number.of.visits,
     df_num_visits_x_mean_points_visit$mean.points.per.visit,
     pch=19,
     col=km$cluster,
     xlab="Total number of visits",
     ylab="Mean points per visit"
)
grid()

## Cluster analysis of total.number.of.visits and mean.number.of.visited.experiment columns

df_num_visits_x_number_of_visited_experiments = df_aggregated_by_user[,c("total.number.of.visits", "mean.number.of.visited.experiment")]

df_num_visits_x_number_of_visited_experiments_Scaled = scale(df_num_visits_x_number_of_visited_experiments)

fviz_nbclust(df_num_visits_x_number_of_visited_experiments_Scaled, kmeans, method = "wss")

km=kmeans(df_num_visits_x_number_of_visited_experiments_Scaled, centers = 5, nstart = 10, iter.max = 100)

grDevices::windows()
plot(df_num_visits_x_number_of_visited_experiments$total.number.of.visits,
     df_num_visits_x_number_of_visited_experiments$mean.number.of.visited.experiment,
     pch=19,
     col=km$cluster,
     xlab="Total number of visits",
     ylab="Mean number of experiments per visit"
)
grid()

### END CLUSTER ANALYSIS



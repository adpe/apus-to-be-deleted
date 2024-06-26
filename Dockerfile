# Stage that builds the application, a prerequisite for the running stage
FROM eclipse-temurin:21 AS build

# Stop running as root at this point
RUN useradd -m apus
WORKDIR /usr/src/app/
RUN chown apus:apus /usr/src/app/
USER apus

# Copy pom.xml and prefetch dependencies so a repeated build can continue from the next step with existing dependencies
COPY --chown=apus pom.xml ./
COPY --chown=apus mvnw ./
COPY --chown=apus .mvn .mvn
RUN ./mvnw dependency:go-offline -Pproduction

# Copy all needed project files to a folder
COPY --chown=apus:apus src src
COPY --chown=apus:apus frontend frontend
COPY --chown=apus:apus package.json ./

# Using * after the files that are autogenerated so that the build won't fail if they are not yet created
COPY --chown=apus:apus package-lock.json* pnpm-lock.yaml* webpack.config.js* ./

# Build the production package, assuming that we validated the version before so no need for running tests again
RUN ./mvnw clean package -DskipTests -Dcheckstyle.skip -Pproduction

# Running stage: the part that is used for running the application
FROM eclipse-temurin:21
COPY --from=build /usr/src/app/target/*.jar /usr/app/app.jar
RUN useradd -m apus
RUN mkdir /home/apus/.apus
USER apus
EXPOSE 8080
CMD java -jar /usr/app/app.jar
HEALTHCHECK CMD curl --fail --silent localhost:8080/actuator/health | grep UP || exit 1

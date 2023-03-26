# Use the official .NET Core SDK as the base image
FROM mcr.microsoft.com/dotnet/sdk:7.0 AS build-env

# Set the working directory
WORKDIR /app

# Copy the project file to the container
COPY *.csproj ./

# Restore dependencies
RUN dotnet restore

# Copy the rest of the project to the container
COPY . ./

# Build the project and publish it
RUN dotnet publish -c Release -o out

# Use the official ASP.NET Core runtime image as the base image
FROM mcr.microsoft.com/dotnet/aspnet:7.0

# Set the working directory
WORKDIR /app

# Copy the published output from the previous stage
COPY --from=build-env /app/out .

# Install CURL
RUN apt-get update && \
    apt-get install -y curl

# Expose port 80 for incoming traffic
EXPOSE 80

# Set the command to run when the container starts
CMD ["dotnet", "HelloWorldAPI.dll"]

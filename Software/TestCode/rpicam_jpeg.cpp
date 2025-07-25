/* SPDX-License-Identifier: BSD-2-Clause */
/*
 * Copyright (C) 2020, Raspberry Pi (Trading) Ltd.
 *
 * rpicam_jpeg.cpp - minimal libcamera jpeg capture app.
 */

#include <chrono>

#include "core/rpicam_app.hpp"
#include "core/still_options.hpp"

#include "image/image.hpp"

using namespace std::placeholders;
using libcamera::Stream;

class RPiCamJpegApp : public RPiCamApp
{
public:
	RPiCamJpegApp()
		: RPiCamApp(std::make_unique<StillOptions>())
	{
	}

	StillOptions *GetOptions() const
	{
		return static_cast<StillOptions *>(options_.get());
	}
};

// The main even loop for the application.

static void event_loop(RPiCamJpegApp &app)
{
	// NEW CODE -- To demonstrate triggering problem
	// Call the set-external-trigger script just before we get started
	std::string trigger_mode_command = "./imx296_trigger 4 1";

	LOG(1, "Ball Watcher - Camera 2 trigger_mode_command = " + trigger_mode_command);
	int command_result = system(trigger_mode_command.c_str());

	if (command_result != 0) {
		LOG(1, "system(trigger_mode_command) failed.");
		return;
	}

	StillOptions const *options = app.GetOptions();
	app.OpenCamera();
	app.ConfigureViewfinder();
	app.StartCamera();
	auto start_time = std::chrono::high_resolution_clock::now();


	for (;;)
	{
		RPiCamApp::Msg msg = app.Wait();

		LOG(1, "Received msg: " + std::to_string((int)msg.type));

		if (msg.type == RPiCamApp::MsgType::Timeout)
		{
			LOG_ERROR("ERROR: Device timeout detected, attempting a restart!!!");
			app.StopCamera();
			app.StartCamera();
			continue;
		}
		if (msg.type == RPiCamApp::MsgType::Quit)
			return;
		else if (msg.type != RPiCamApp::MsgType::RequestComplete)
			throw std::runtime_error("unrecognised message!");

		// In viewfinder mode, simply run until the timeout. When that happens, switch to
		// capture mode.
		if (app.ViewfinderStream())
		{
			LOG(1, "In ViewfinderStream mode.");
			auto now = std::chrono::high_resolution_clock::now();
			if (options->timeout && (now - start_time) > options->timeout.value)
			{
				app.StopCamera();
				app.Teardown();
				app.ConfigureStill();
				app.StartCamera();
			}
			else
			{
				CompletedRequestPtr &completed_request = std::get<CompletedRequestPtr>(msg.payload);
				app.ShowPreview(completed_request, app.ViewfinderStream());
			}
		}
		// In still capture mode, save a jpeg and quit.
		else if (app.StillStream())
		{
			// NEW CODE -- To demonstrate triggering problem
			// Continue waiting for message to help show the triggering problem
			// app.StopCamera();
			LOG(1, "Still capture image received");

			Stream *stream = app.StillStream();
			StreamInfo info = app.GetStreamInfo(stream);
			CompletedRequestPtr &payload = std::get<CompletedRequestPtr>(msg.payload);
			BufferReadSync r(&app, payload->buffers[stream]);
			const std::vector<libcamera::Span<uint8_t>> mem = r.Get();
			jpeg_save(mem, info, payload->metadata, options->output, app.CameraModel(), options);

			// Continue waiting for message to help show the triggering problem
			// return;
		}
	}
}

int main(int argc, char *argv[])
{
	try
	{
		RPiCamJpegApp app;
		StillOptions *options = app.GetOptions();
		if (options->Parse(argc, argv))
		{
			if (options->verbose >= 2)
				options->Print();
			if (options->output.empty())
				throw std::runtime_error("output file name required");

			event_loop(app);
		}
	}
	catch (std::exception const &e)
	{
		LOG_ERROR("ERROR: *** " << e.what() << " ***");
		return -1;
	}
	return 0;
}

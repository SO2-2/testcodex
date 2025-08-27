#include <FL/Fl.H>
#include <FL/Fl_Window.H>
#include <FL/Fl_Button.H>
#include <FL/Fl_Input.H>
#include <FL/Fl_Choice.H>
#include <FL/Fl_Text_Display.H>
#include <FL/Fl_Text_Buffer.H>

#include <cstdio>
#include <string>

class MainWindow : public Fl_Window {
public:
    MainWindow()
        : Fl_Window(400, 300, "Package Manager GUI") {
        begin();

        choice = new Fl_Choice(100, 20, 200, 25, "Manager:");
        choice->add("winget");
        choice->add("choco");
        choice->add("npm");
        choice->value(0);

        input = new Fl_Input(100, 60, 200, 25, "Package:");

        output_buffer = new Fl_Text_Buffer();
        output = new Fl_Text_Display(20, 100, 360, 140);
        output->buffer(output_buffer);

        auto *button = new Fl_Button(150, 250, 100, 30, "Install");
        button->callback(run_cb, this);

        end();
    }

private:
    static void run_cb(Fl_Widget *, void *userdata) {
        static_cast<MainWindow *>(userdata)->runCommand();
    }

    void runCommand() {
        const char *pkg = input->value();
        if (!pkg || pkg[0] == '\0') return;

        const char *manager = choice->text(choice->value());
        std::string command;
        if (std::string(manager) == "winget") {
            command = "winget install " + std::string(pkg);
        } else if (std::string(manager) == "choco") {
            command = "choco install " + std::string(pkg) + " -y";
        } else if (std::string(manager) == "npm") {
            command = "npm install -g " + std::string(pkg);
        }

        FILE *pipe = popen(command.c_str(), "r");
        if (!pipe) return;
        char buffer[128];
        std::string result;
        while (fgets(buffer, sizeof(buffer), pipe)) {
            result += buffer;
        }
        pclose(pipe);
        output_buffer->append(result.c_str());
    }

    Fl_Choice *choice;
    Fl_Input *input;
    Fl_Text_Display *output;
    Fl_Text_Buffer *output_buffer;
};

int main(int argc, char **argv) {
    MainWindow win;
    win.show(argc, argv);
    return Fl::run();
}

